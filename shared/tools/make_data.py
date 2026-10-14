#!/usr/bin/env python3
"""Build the data the Dive Malta apps bundle (iOS now, Android later) into ../data/.

- malta-dive-sites.json (+ .geojson for the map): OSM dive sites around Malta, Gozo and Comino, taken from
  OpenStreetMap (via Overpass, cached in cache/osm-dive-sites.json), plus places around Malta whose
  name says they are a dive site ("... (Dive Site)") but which OSM tags as a reef, statue etc. Dive
  centres, shops and clubs are left out, using the same rules as the Garmin map.
- malta-depth.bin / malta-depth.json: the EMODnet Bathymetry DTM (about 115 m grid) resampled to
  ~38 m, with land and sea taken from the OSM coastline. EMODnet's own coastline is only as good as
  its 115 m cells, so it puts land in the sea and sea on land in places (e.g. around MV Xlendi).
  Depths in decimetres as little-endian Int16, land = 32767, no data = -32768 (sea per OSM but
  land per EMODnet, so EMODnet has no depth there), rows north to south.
- malta-contours.geojson: depth contours at diving depths traced from that grid. EMODnet's own
  contour layer only has 50/100/200/500 m.

Our own additions in ../enrichment/ (see its README) are merged over the OSM and EMODnet data:
extra or corrected dive sites, areas with a known depth, and extra map lines (malta-extras.geojson).

Standard library only.
"""
import json
import math
import re
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from osm_rules import depth_of, entry_of, is_centre_like, site_type  # noqa: E402

# Everything the apps bundle lives in one folder; the map style refers to it as {ASSETS}.
OUT = MAP = os.path.join(HERE, "..", "data")
ENRICH = os.path.join(HERE, "..", "enrichment")
CACHE = os.path.join(HERE, "cache")  # downloaded EMODnet grid and OSM coastline; delete to refresh

# Malta, Gozo and Comino with some sea around them.
MIN_LON, MAX_LON, MIN_LAT, MAX_LAT = 14.10, 14.65, 35.75, 36.12
LEVELS = [5, 10, 15, 20, 30, 40, 50, 60, 80, 100, 150, 200]
SAME_SITE_M = 200      # sites with the same name this close together are one site mapped twice
MIN_LINE_M = 300       # drop contour scraps shorter than this
SMOOTHING = 1          # Chaikin passes; rounds off the grid's staircase corners
UPSAMPLE = 3           # resample the 115 m EMODnet grid to ~38 m so it can follow the coastline
LAND = 32767
NO_DATA = -32768

OVERPASS = ["https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter"]

WCS = ("https://ows.emodnet-bathymetry.eu/wcs?service=WCS&request=GetCoverage&version=2.0.1"
       "&coverageId=emodnet__mean&format=text/plain"
       f"&subset=Lat({MIN_LAT},{MAX_LAT})&subset=Long({MIN_LON},{MAX_LON})")


# --- dive sites -------------------------------------------------------------------------------

DIVE_SITE_WORDS = re.compile(r"\s*\(\s*div(e|ing) site\s*\)|\s+div(e|ing) site$|^div(e|ing) site\s+", re.I)


def says_dive_site(name):
    return bool(name and DIVE_SITE_WORDS.search(name))


def clean_name(name):
    """'Filfla (Dive Site)', "Alex's Cave Dive Site", 'diving site Għar Lapsi' -> the place name."""
    if not name:
        return name
    cleaned = DIVE_SITE_WORDS.sub("", name).strip(" -")
    # 'Dive Site and Shipwreck' has no place name to keep, so it stays as it is.
    return cleaned if cleaned and not cleaned[0].islower() else name


def dive_site_type(tags, known_dive_site):
    """Like site_type, but for places we know are dive sites (by name, or listed in ../enrichment)
    natural=reef only says a mapper put the dive site on the map as a reef, so it's not a site type."""
    if known_dive_site and tags.get("natural") == "reef":
        tags = {k: v for k, v in tags.items() if k != "natural"}
    return site_type(tags)


def site_record(osm_id, lon, lat, tags):
    raw = tags.get("name") or tags.get("name:en") or tags.get("scuba_diving:name")
    return {
        "id": osm_id,
        "name": clean_name(raw),
        "lat": lat, "lon": lon,
        "maxDepth": depth_of(tags),
        "type": dive_site_type(tags, says_dive_site(raw)),
        "entry": entry_of(tags),
        "tags": tags,
    }


def named_dive_sites():
    """OSM places around Malta named as a dive site but not tagged sport=scuba_diving."""
    query = (f'[out:json][timeout:60];nwr["name"~"[Dd]iv(e|ing) [Ss]ite"]'
             f"({MIN_LAT},{MIN_LON},{MAX_LAT},{MAX_LON});out center tags;")
    body = urllib.parse.urlencode({"data": query}).encode()

    def download():
        for url in OVERPASS:
            try:
                return fetch(urllib.request.Request(url, data=body, headers={"User-Agent": "DiveMalta-data/1.0"}))
            except Exception as e:
                print(f"  {url} failed: {e}", file=sys.stderr)
        sys.exit("All Overpass endpoints failed.")

    for el in json.loads(cached("osm-named-dive-sites.json", download))["elements"]:
        c = el if "lat" in el else el.get("center")
        if el["type"] == "relation" or not c:   # e.g. the "Gozo Dive Sites" collection
            continue
        yield site_record(f"{el['type']}/{el['id']}", c["lon"], c["lat"], el.get("tags", {}))


def osm_dive_sites():
    """OSM dive sites around Malta: sport=scuba_diving / free_diving / snorkeling, without dive centres."""
    query = (f'[out:json][timeout:120];nwr["sport"~"(^|;)(scuba_diving|free_diving|snorkeling)(;|$)"]'
             f"({MIN_LAT},{MIN_LON},{MAX_LAT},{MAX_LON});out center tags;")
    body = urllib.parse.urlencode({"data": query}).encode()

    def download():
        for url in OVERPASS:
            try:
                return fetch(urllib.request.Request(url, data=body, headers={"User-Agent": "DiveMalta-data/1.0"}))
            except Exception as e:
                print(f"  {url} failed: {e}", file=sys.stderr)
        sys.exit("All Overpass endpoints failed.")

    for el in json.loads(cached("osm-dive-sites.json", download))["elements"]:
        c = el if "lat" in el else el.get("center")
        tags = el.get("tags", {})
        if not c or tags.get("amenity") == "dive_centre" or tags.get("shop") == "scuba_diving" or is_centre_like(tags):
            continue
        yield site_record(f"{el['type']}/{el['id']}", c["lon"], c["lat"], tags)


def make_sites():
    sites = list(osm_dive_sites())
    known = {s["id"] for s in sites}
    extra = [s for s in named_dive_sites() if s["id"] not in known and not is_centre_like(s["tags"])]
    print(f"  {len(extra)} more sites named as dive sites: {', '.join(s['name'] for s in extra)}", file=sys.stderr)
    sites += extra
    sites = enrich_sites(merge_duplicates(sites))
    sites.sort(key=lambda s: (s["name"] or "~").lower())
    with open(os.path.join(OUT, "malta-dive-sites.json"), "w") as f:
        json.dump(sites, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(MAP, "malta-dive-sites.geojson"), "w") as f:
        json.dump({"type": "FeatureCollection", "features": [
            {"type": "Feature", "geometry": {"type": "Point", "coordinates": [s["lon"], s["lat"]]},
             "properties": {"id": s["id"], "name": s["name"] or "Dive site", "type": s["type"] or "site"}}
            for s in sites]}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(sites)} dive sites", file=sys.stderr)


def load_enrichment(name, default):
    path = os.path.join(ENRICH, name)
    if not os.path.exists(path):
        return default
    with open(path) as f:
        return json.load(f)


def enrich_sites(sites):
    """Apply ../enrichment/sites.json: update or remove sites by id, add new ones."""
    by_id = {s["id"]: s for s in sites}
    for entry in load_enrichment("sites.json", []):
        site = by_id.get(entry["id"])
        if entry.get("remove"):
            if site:
                sites.remove(site)
                print(f"  enrichment: removed {entry['id']}", file=sys.stderr)
            continue
        if site is None:
            tags = {"name": entry["name"], **entry.get("tags", {})}
            site = {"id": entry["id"], "name": entry["name"], "lat": entry["lat"], "lon": entry["lon"],
                    "maxDepth": depth_of(tags), "type": dive_site_type(tags, True), "entry": entry_of(tags), "tags": tags}
            sites.append(site)
            by_id[site["id"]] = site
            action = "added"
        else:
            site["tags"].update(entry.get("tags", {}))
            site["type"] = dive_site_type(site["tags"], True)   # listed by us, so it is a dive site
            action = "updated"
        for field in ("name", "lat", "lon", "maxDepth", "type", "entry"):
            if field in entry:
                site[field] = entry[field]
        print(f"  enrichment: {action} {site['name']} ({site['id']})", file=sys.stderr)
    return sites


def merge_duplicates(sites):
    """Merge sites mapped twice in OSM (same or alternative name, close together, e.g. Billinghurst Cave
    as both the entry ladder and the cave). The entry with the most tags is kept; tags only the other one has
    are added to it."""
    kept = []
    for site in sorted(sites, key=lambda s: -len(s["tags"])):
        twin = next((k for k in kept if same_site_name(k, site) and distance_m(k, site) < SAME_SITE_M), None)
        if twin is None:
            kept.append(site)
            continue
        for key, value in site["tags"].items():
            twin["tags"].setdefault(key, value)
        for field in ("maxDepth", "type", "entry"):
            twin[field] = twin[field] or site[field]
        print(f"  merged duplicate {site['name']} ({site['id']} into {twin['id']})", file=sys.stderr)
    return kept


NAME_KEYS = ("name", "alt_name", "name:en", "old_name", "official_name")


def same_site_name(a, b):
    """True when any of the two sites' names match, including OSM's alternative and English names
    ('Blue Hole (Dive Site)' == 'Il-Ħofra tal-Bidwin', alt_name 'Blue Hole'). '(Dive Site)',
    punctuation, case and word order are ignored ('Little Bear & Big Bear' == 'Big Bear-Little Bear')."""
    def words(name):
        name = re.sub(r"\(?\b(dive|diving) site\b\)?", " ", name.lower())
        return frozenset(re.findall(r"\w+", name))

    def names(site):
        values = [site["name"]] + [site["tags"].get(k) for k in NAME_KEYS]
        return {words(n) for v in values if v for n in v.split(";")} - {frozenset()}

    return bool(names(a) & names(b))


def distance_m(a, b):
    dx = (a["lon"] - b["lon"]) * 111_320 * math.cos(math.radians(a["lat"]))
    return math.hypot(dx, (a["lat"] - b["lat"]) * 111_320)


# --- depth contours ---------------------------------------------------------------------------

def fetch(req):
    with urllib.request.urlopen(req, timeout=180) as resp:
        return resp.read().decode()


def cached(name, download):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        text = download()
        with open(path, "w") as f:
            f.write(text)
    with open(path) as f:
        return f.read()


def load_grid():
    """Returns (rows, lon0, lat0, step): rows[r][c] is the elevation (negative = depth) of the
    cell centre at (lon0 + c*step, lat0 - r*step)."""
    text = cached("emodnet-grid.txt", lambda: fetch(urllib.request.Request(
        WCS, headers={"User-Agent": "DiveMalta-data/1.0"})))
    params = {}
    for line in text.splitlines():
        if 'PARAMETER["elt_' in line:
            key = line.split('"')[1]
            params[key] = float(line.split(",")[1].strip(" ]),"))
    body = text.split("Band 0:", 1)[1]
    rows = [[float(v) for v in line.split()] for line in body.strip().splitlines() if line.strip()]
    # The affine maps grid indices to cell centres, but the indices don't start at 0
    # ("Grid range: GridEnvelope2D[0..527, 1..355]"), so shift to the first column and row.
    m = re.search(r"GridEnvelope2D\[(-?\d+)\.\.\d+, (-?\d+)\.\.\d+\]", text)
    col0, row0 = int(m.group(1)), int(m.group(2))
    lon0 = params["elt_0_2"] + col0 * params["elt_0_0"]
    lat0 = params["elt_1_2"] + row0 * params["elt_1_1"]
    return rows, lon0, lat0, params["elt_0_0"]


def load_coastline():
    """OSM coastline around Malta as closed rings of (lon, lat)."""
    query = (f"[out:json][timeout:120];way[natural=coastline]"
             f"({MIN_LAT},{MIN_LON},{MAX_LAT},{MAX_LON});out geom;")
    body = urllib.parse.urlencode({"data": query}).encode()

    def download():
        for url in OVERPASS:
            try:
                return fetch(urllib.request.Request(url, data=body, headers={"User-Agent": "DiveMalta-data/1.0"}))
            except Exception as e:
                print(f"  {url} failed: {e}", file=sys.stderr)
        sys.exit("All Overpass endpoints failed.")

    ways = json.loads(cached("osm-coastline.json", download))["elements"]

    # Join ways end to start into rings.
    by_start = {w["nodes"][0]: w for w in ways}
    rings, used = [], set()
    for w in ways:
        if w["id"] in used:
            continue
        ring, cur = [], w
        while cur and cur["id"] not in used:
            used.add(cur["id"])
            ring += [(g["lon"], g["lat"]) for g in cur["geometry"]][1 if ring else 0:]
            cur = by_start.get(cur["nodes"][-1])
        rings.append(ring)
    return rings


def land_mask(rings, n_rows, n_cols, lon0, lat0, step):
    """mask[r][c] is True where the cell centre is on land (inside a coastline ring)."""
    crossings = [[] for _ in range(n_rows)]
    for ring in rings:
        for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
            if y1 == y2:
                continue
            # Rows whose centre latitude lies in [min(y1,y2), max(y1,y2)).
            r_from = math.ceil((lat0 - max(y1, y2)) / step)
            r_to = math.floor((lat0 - min(y1, y2)) / step)
            for r in range(max(r_from, 0), min(r_to, n_rows - 1) + 1):
                y = lat0 - r * step
                if min(y1, y2) <= y < max(y1, y2):
                    crossings[r].append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
    mask = []
    for r in range(n_rows):
        row, xs = [False] * n_cols, sorted(crossings[r])
        for a, b in zip(xs[::2], xs[1::2]):
            c_from = max(0, math.ceil((a - lon0) / step))
            c_to = min(n_cols - 1, math.floor((b - lon0) / step))
            for c in range(c_from, c_to + 1):
                row[c] = True
        mask.append(row)
    return mask


def upsample(rows, factor):
    """Bilinear resampling between the original cell centres."""
    n_rows, n_cols = len(rows), len(rows[0])
    out = []
    for R in range((n_rows - 1) * factor + 1):
        r, fr = divmod(R, factor)
        r2, t = min(r + 1, n_rows - 1), fr / factor
        top, bottom = rows[r], rows[r2]
        line = []
        for C in range((n_cols - 1) * factor + 1):
            c, fc = divmod(C, factor)
            c2, u = min(c + 1, n_cols - 1), fc / factor
            a = top[c] + (top[c2] - top[c]) * u
            b = bottom[c] + (bottom[c2] - bottom[c]) * u
            line.append(a + (b - a) * t)
        out.append(line)
    return out


def corrected_grid():
    """EMODnet elevations on a finer grid, with land and sea from the OSM coastline."""
    rows, lon0, lat0, step = load_grid()
    print(f"EMODnet grid {len(rows[0])} x {len(rows)}, step {step * 3600:.2f}\"", file=sys.stderr)
    # Where EMODnet has land we use the raw elevations (their zero line is EMODnet's coast); for the
    # depths, land is flattened to sea level so resampling doesn't drag hilltops into the shallows.
    raw = upsample(rows, UPSAMPLE)
    rows = upsample([[min(v, 0.0) for v in row] for row in rows], UPSAMPLE)
    step /= UPSAMPLE
    rings = load_coastline()
    mask = land_mask(rings, len(rows), len(rows[0]), lon0, lat0, step)
    land = no_data = 0
    for r, row in enumerate(rows):
        for c in range(len(row)):
            if mask[r][c]:
                row[c] = 1.0
                land += raw[r][c] < 0
            elif raw[r][c] >= 0:
                row[c] = math.nan
                no_data += 1
    print(f"Grid {len(rows[0])} x {len(rows)}, {len(rings)} coastline rings; "
          f"{land} cells EMODnet had as sea are land, {no_data} sea cells EMODnet has as land (no data)",
          file=sys.stderr)

    # Our own known depths win over both OSM and EMODnet.
    for feature in load_enrichment("depths.geojson", {"features": []})["features"]:
        depth = feature["properties"]["depth_m"]
        inside = land_mask([[tuple(p) for p in feature["geometry"]["coordinates"][0]]],
                           len(rows), len(rows[0]), lon0, lat0, step)
        cells = 0
        for r, row in enumerate(inside):
            for c, hit in enumerate(row):
                if hit:
                    rows[r][c] = -depth
                    cells += 1
        print(f"  enrichment: {feature['properties'].get('name', 'area')} at {depth} m ({cells} cells)",
              file=sys.stderr)
    return rows, lon0, lat0, step


def write_extras():
    """../enrichment/map.geojson -> ../data/malta-extras.geojson for the map style."""
    extras = load_enrichment("map.geojson", {"type": "FeatureCollection", "features": []})
    for feature in extras["features"]:
        feature["properties"].pop("note", None)
    with open(os.path.join(MAP, "malta-extras.geojson"), "w") as f:
        json.dump(extras, f, ensure_ascii=False, separators=(",", ":"))


def write_grid(rows, lon0, lat0, step):
    import array
    values = array.array("h", (NO_DATA if math.isnan(v) else LAND if v > 0 else max(-32000, round(v * 10))
                               for row in rows for v in row))
    if sys.byteorder != "little":
        values.byteswap()
    with open(os.path.join(OUT, "malta-depth.bin"), "wb") as f:
        values.tofile(f)
    with open(os.path.join(OUT, "malta-depth.json"), "w") as f:
        json.dump({"cols": len(rows[0]), "rows": len(rows), "lon0": lon0, "lat0": lat0, "step": step,
                   "land": LAND, "noData": NO_DATA, "source": "EMODnet Bathymetry DTM + OSM coastline"}, f)


# Corner bits: top-left 1, top-right 2, bottom-right 4, bottom-left 8. Edges: T, R, B, L.
CASES = {
    1: [("L", "T")], 2: [("T", "R")], 3: [("L", "R")], 4: [("R", "B")], 5: [("L", "T"), ("R", "B")],
    6: [("T", "B")], 7: [("L", "B")], 8: [("L", "B")], 9: [("T", "B")], 10: [("T", "R"), ("B", "L")],
    11: [("R", "B")], 12: [("L", "R")], 13: [("T", "R")], 14: [("L", "T")],
}


def trace(rows, level):
    """Marching squares for elevation == level; returns chains of edge keys. Cells touching a
    no-data (NaN) corner are skipped, so lines stop where EMODnet has no depth."""
    n_rows, n_cols = len(rows), len(rows[0])
    neighbours = {}
    for r in range(n_rows - 1):
        top, bottom = rows[r], rows[r + 1]
        for c in range(n_cols - 1):
            if top[c] != top[c] or top[c + 1] != top[c + 1] or bottom[c] != bottom[c] or bottom[c + 1] != bottom[c + 1]:
                continue
            idx = ((top[c] < level) | (top[c + 1] < level) << 1
                   | (bottom[c + 1] < level) << 2 | (bottom[c] < level) << 3)
            for a, b in CASES.get(idx, ()):
                ka, kb = edge_key(r, c, a), edge_key(r, c, b)
                neighbours.setdefault(ka, []).append(kb)
                neighbours.setdefault(kb, []).append(ka)
    chains, seen = [], set()
    # Start at open ends first so open lines come out whole; then the closed rings.
    starts = [k for k, v in neighbours.items() if len(v) == 1] + list(neighbours)
    for start in starts:
        if start in seen:
            continue
        chain, prev, cur = [start], None, start
        seen.add(start)
        while True:
            nxt = next((k for k in neighbours[cur] if k != prev and k not in seen), None)
            if nxt is None:
                if len(chain) > 2 and start in neighbours[cur]:
                    chain.append(start)  # close the ring
                break
            chain.append(nxt)
            seen.add(nxt)
            prev, cur = cur, nxt
        chains.append(chain)
    return chains


def edge_key(r, c, edge):
    # Horizontal edges ("h", r, c) join (r,c)-(r,c+1); vertical ("v", r, c) join (r,c)-(r+1,c).
    return {"T": ("h", r, c), "B": ("h", r + 1, c), "L": ("v", r, c), "R": ("v", r, c + 1)}[edge]


def edge_point(rows, key, level, lon0, lat0, step):
    kind, r, c = key
    r2, c2 = (r, c + 1) if kind == "h" else (r + 1, c)
    a, b = rows[r][c], rows[r2][c2]
    t = 0.5 if a == b else (level - a) / (b - a)
    col, row = c + t * (c2 - c), r + t * (r2 - r)
    return (round(lon0 + col * step, 6), round(lat0 - row * step, 6))


def smooth(coords):
    """Chaikin corner cutting. Keeps the ends of open lines; closed rings stay closed."""
    closed = coords[0] == coords[-1]
    for _ in range(SMOOTHING):
        pts = coords[:-1] if closed else coords
        pairs = list(zip(pts, pts[1:] + pts[:1])) if closed else list(zip(pts, pts[1:]))
        out = [] if closed else [pts[0]]
        for (x1, y1), (x2, y2) in pairs:
            out.append((0.75 * x1 + 0.25 * x2, 0.75 * y1 + 0.25 * y2))
            out.append((0.25 * x1 + 0.75 * x2, 0.25 * y1 + 0.75 * y2))
        coords = out + ([out[0]] if closed else [pts[-1]])
    return [(round(x, 5), round(y, 5)) for x, y in coords]


def length_m(coords):
    total = 0.0
    for (x1, y1), (x2, y2) in zip(coords, coords[1:]):
        dx = (x2 - x1) * 111_320 * math.cos(math.radians(y1))
        dy = (y2 - y1) * 111_320
        total += math.hypot(dx, dy)
    return total


def make_contours(rows, lon0, lat0, step):
    features = []
    for depth in LEVELS:
        lines = 0
        for chain in trace(rows, -depth):
            coords = smooth([edge_point(rows, k, -depth, lon0, lat0, step) for k in chain])
            length = length_m(coords)
            if length < MIN_LINE_M:
                continue
            lines += 1
            features.append({"type": "Feature", "properties": {"depth": depth},
                             "geometry": {"type": "LineString", "coordinates": coords}})
        print(f"  {depth} m: {lines} lines", file=sys.stderr)
    with open(os.path.join(MAP, "malta-contours.geojson"), "w") as f:
        json.dump({"type": "FeatureCollection", "features": features}, f, separators=(",", ":"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_sites()
    write_extras()
    grid = corrected_grid()
    write_grid(*grid)
    make_contours(*grid)
