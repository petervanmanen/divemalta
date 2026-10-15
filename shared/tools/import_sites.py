#!/usr/bin/env python3
"""Add dive sites from OpenStreetMap that aren't in shared/sites/ yet, one new file each.

Existing files are never changed, so edits to them are safe. An OSM entry is skipped when its id is
already used by a site file (its "id" or one of "osm.ids", which also lists merged duplicates) or
listed in shared/sites/_ignored.json. New files get what OSM knows (position, depth, type, entry,
website) and an empty research section to fill in by hand.

    python3 shared/tools/import_sites.py            # uses the cached OSM download (tools/cache/)
    python3 shared/tools/import_sites.py --refresh  # download the OSM data again first

Which OSM entries count as dive sites, and how duplicates are merged, is in make_data.py and
osm_rules.py.
"""
import glob
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_data as md  # noqa: E402

SITES = os.path.join(HERE, "..", "sites")


def slug(name):
    t = name.replace("'", "").replace("’", "")
    for a, b in {"Ħ": "H", "ħ": "h", "Ġ": "G", "ġ": "g", "Ż": "Z", "ż": "z", "Ċ": "C", "ċ": "c"}.items():
        t = t.replace(a, b)
    t = unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-") or "dive-site"


def main():
    if "--refresh" in sys.argv:
        for name in ("osm-dive-sites.json", "osm-named-dive-sites.json"):
            path = os.path.join(md.CACHE, name)
            if os.path.exists(path):
                os.remove(path)
    known = set(json.load(open(os.path.join(SITES, "_ignored.json")))["ids"])
    for path in glob.glob(os.path.join(SITES, "[!_]*.json")):
        site = json.load(open(path))
        known.add(site["id"])
        known.update(site.get("osm", {}).get("ids", []))

    osm = list(md.osm_dive_sites())
    seen = {s["id"] for s in osm}
    osm += [s for s in md.named_dive_sites() if s["id"] not in seen and not md.is_centre_like(s["tags"])]
    added = 0
    for s in md.merge_duplicates(osm):
        ids = [s["id"], *s.get("mergedIds", [])]
        if any(i in known for i in ids):
            continue
        t = s["tags"]
        site = {
            "id": s["id"], "name": s["name"] or "Dive site", "lat": round(s["lat"], 7), "lon": round(s["lon"], 7),
            "type": s["type"], "maxDepth": s["maxDepth"], "entry": s["entry"],
            "website": t.get("website") or t.get("contact:website") or t.get("url"),
            "description": t.get("description"),
            "note": "Imported from OpenStreetMap; not researched yet.",
            "osm": {"ids": ids, "tags": t},
        }
        site = {k: v for k, v in site.items() if v not in (None, "", [])}
        base = slug(site["name"]); name = base; i = 2
        while os.path.exists(os.path.join(SITES, f"{name}.json")):
            name = f"{base}-{i}"; i += 1
        with open(os.path.join(SITES, f"{name}.json"), "w", encoding="utf-8") as f:
            json.dump(site, f, ensure_ascii=False, indent=2); f.write("\n")
        print(f"  added {name}.json ({site['name']}, {site['id']})")
        added += 1
    print(f"{added} new dive sites from OpenStreetMap", file=sys.stderr)


if __name__ == "__main__":
    main()
