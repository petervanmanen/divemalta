#!/usr/bin/env python3
"""Gather the dive sites: read every shared/sites/*.json (one file per site) and write what the apps
bundle. Both apps run this while building (Xcode build phase, Gradle task), so the site files are the
content: add, edit or delete a file and the next build has it.

    gather_sites.py <sites folder> <output folder>

Writes into the output folder:
- malta-dive-sites.json     all sites (without the "note" and "osm" fields), sorted by name
- malta-dive-sites.geojson  points for the map (id, name, type)

Files starting with "_" are skipped. A broken file stops the build with the file name and the problem.
Standard library only.
"""
import json
import os
import sys

REQUIRED = {"id": str, "name": str, "lat": (int, float), "lon": (int, float)}
OPTIONAL = {
    "type": str, "maxDepth": str, "typicalDepth": str, "level": str, "entry": str, "shoreAccess": str,
    "difficulty": str, "description": str, "conditions": str, "website": str, "sources": list,
    "note": str, "osm": dict,
}
TYPES = {"wreck", "cave", "reef", "statue", "wall", "rocks", "quarry", "lake", "drift", "training", "attraction", "boat"}
ENTRIES = {"shore", "boat"}
# Not bundled: notes for us and the original OpenStreetMap data.
PRIVATE = {"note", "osm"}
# Roughly Malta, Gozo and Comino with the sea around them (the area the bundled map covers).
BOUNDS = (35.75, 36.12, 14.10, 14.65)


def fail(path, message):
    sys.exit(f"error: {path}: {message}")


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            site = json.load(f)
    except json.JSONDecodeError as e:
        fail(path, f"not valid JSON (line {e.lineno}, column {e.colno}: {e.msg})")
    if not isinstance(site, dict):
        fail(path, "should contain one JSON object")
    for key, kind in REQUIRED.items():
        if not isinstance(site.get(key), kind) or site.get(key) in ("", None):
            fail(path, f'"{key}" is missing or has the wrong type')
    for key, value in site.items():
        if key not in REQUIRED and key not in OPTIONAL:
            fail(path, f'unknown field "{key}" (known: {", ".join([*REQUIRED, *OPTIONAL])})')
        if key in OPTIONAL and value is not None and not isinstance(value, OPTIONAL[key]):
            fail(path, f'"{key}" has the wrong type')
    if not (BOUNDS[0] <= site["lat"] <= BOUNDS[1] and BOUNDS[2] <= site["lon"] <= BOUNDS[3]):
        fail(path, "lat/lon is outside the area of the map (Malta, Gozo and Comino)")
    if site.get("type") not in (None, *TYPES):
        fail(path, f'"type" should be one of {", ".join(sorted(TYPES))}')
    if site.get("entry") not in (None, *ENTRIES):
        fail(path, '"entry" should be "shore" or "boat"')
    if not all(isinstance(s, str) and s.startswith("http") for s in site.get("sources", [])):
        fail(path, '"sources" should be a list of URLs')
    return site


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    folder, out = sys.argv[1], sys.argv[2]
    files = sorted(f for f in os.listdir(folder) if f.endswith(".json") and not f.startswith("_"))
    sites, ids = [], {}
    for name in files:
        path = os.path.join(folder, name)
        site = load(path)
        if site["id"] in ids:
            fail(path, f'id "{site["id"]}" is also used by {ids[site["id"]]}')
        ids[site["id"]] = name
        sites.append({k: v for k, v in site.items() if k not in PRIVATE and v not in (None, "", [])})
    sites.sort(key=lambda s: s["name"].lower())

    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "malta-dive-sites.json"), "w", encoding="utf-8") as f:
        json.dump(sites, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(out, "malta-dive-sites.geojson"), "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": [
            {"type": "Feature", "geometry": {"type": "Point", "coordinates": [s["lon"], s["lat"]]},
             "properties": {"id": s["id"], "name": s["name"], "type": s.get("type", "site")}}
            for s in sites]}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"gather_sites: {len(sites)} dive sites -> {out}")


if __name__ == "__main__":
    main()
