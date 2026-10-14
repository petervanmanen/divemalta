#!/usr/bin/env python3
"""Download all OSM dive sites and dive centres worldwide, and cut out Europe into europe-dive-sites.geojson.

The worldwide download (one Overpass query for sport=scuba_diving/free_diving/snorkeling,
amenity=dive_centre and shop=scuba_diving) is cached in cache/world-dive-sites.geojson; pass --refresh
to download it again. A direct Overpass query by country boundaries is too heavy for the public
servers, so we filter locally instead.

"Europe" is a hand-drawn outline: it follows the Mediterranean between Europe and Africa (Malta,
Pantelleria, Lampedusa, Crete and Cyprus are in; Tunisia, Algeria, Libya and Egypt are out), takes in
Turkey, and runs east to 45°E (so European Russia and western Georgia are in). The Canary Islands,
Madeira and the Azores are added as separate boxes; Greenland is left out.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
WORLD = os.path.join(HERE, "cache", "world-dive-sites.geojson")
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
QUERY = """
[out:json][timeout:600];
(
  nwr["sport"~"(^|;)(scuba_diving|free_diving|snorkeling)(;|$)"];
  nwr["amenity"="dive_centre"];
  nwr["shop"="scuba_diving"];
);
out center tags;
"""

# (lon, lat) vertices, clockwise from the south-west.
EUROPE = [
    (-32, 36.0), (-5.9, 36.0), (-0.5, 36.4), (0.0, 37.8), (10.0, 37.8), (11.5, 37.3), (11.5, 35.3),
    (12.0, 34.5), (34.7, 34.5), (34.7, 36.9), (44.8, 37.3), (45, 41.0), (45, 82), (-10, 82),
    (-10, 70), (-20, 66.8), (-32, 66.8),
]
# (min_lon, min_lat, max_lon, max_lat)
EXTRA_BOXES = {
    "Canary Islands": (-18.5, 27.4, -13.2, 29.6),
    "Madeira": (-17.5, 32.3, -16.0, 33.3),
}


def in_polygon(lon, lat, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def in_europe(lon, lat):
    return in_polygon(lon, lat, EUROPE) or any(
        a <= lon <= c and b <= lat <= d for a, b, c, d in EXTRA_BOXES.values())


def download_world():
    data = None
    for url in ENDPOINTS:
        try:
            print(f"Querying {url} (this can take a few minutes)...", file=sys.stderr)
            body = urllib.parse.urlencode({"data": QUERY}).encode()
            req = urllib.request.Request(url, data=body, headers={"User-Agent": "dive-sites-garmin/1.0"})
            with urllib.request.urlopen(req, timeout=700) as resp:
                data = json.load(resp)
            break
        except Exception as e:
            print(f"  failed: {e}", file=sys.stderr)
    if data is None:
        sys.exit("All Overpass endpoints failed.")
    features = []
    for el in data["elements"]:
        c = el if "lat" in el else el.get("center")
        if not c:
            continue
        tags = el.get("tags", {})
        centre = tags.get("amenity") == "dive_centre" or tags.get("shop") == "scuba_diving"
        features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [round(c["lon"], 6), round(c["lat"], 6)]},
            "properties": {"osm": f"{el['type']}/{el['id']}", "kind": "centre" if centre else "site", "tags": tags},
        })
    os.makedirs(os.path.dirname(WORLD), exist_ok=True)
    with open(WORLD, "w") as f:
        json.dump({"type": "FeatureCollection", "features": features}, f, separators=(",", ":"))
    print(f"Downloaded {len(features)} features worldwide", file=sys.stderr)


def main():
    os.chdir(HERE)
    if "--refresh" in sys.argv or not os.path.exists(WORLD):
        download_world()
    with open(WORLD) as f:
        world = json.load(f)
    features = [f for f in world["features"] if in_europe(*f["geometry"]["coordinates"])]
    with open("europe-dive-sites.geojson", "w") as f:
        json.dump({"type": "FeatureCollection", "features": features}, f, separators=(",", ":"))
    sites = sum(1 for x in features if x["properties"]["kind"] == "site")
    print(f"Wrote {len(features)} features ({sites} sites, {len(features) - sites} centres)", file=sys.stderr)


if __name__ == "__main__":
    main()
