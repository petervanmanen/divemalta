# Shared data and tools

Everything here is used by every app. `sites/` holds the dive sites, one JSON file each (see
[sites/README.md](sites/README.md)); both apps gather them while building. `data/` is the rest of
what the apps bundle (the iOS project copies the
whole folder into the app as `data/`; the Android app should do the same with its assets). The map
style refers to that folder as `{ASSETS}`, which each app replaces with the folder's location at
startup.

## What's in data/

| File | What | Made by |
|---|---|---|
| (`malta-dive-sites.json` / `.geojson`) | the dive sites, gathered from `sites/` at build time (not in this folder) | `tools/gather_sites.py` |
| `malta.pmtiles` | OpenStreetMap vector tiles of Malta, Gozo and Comino (8 MB) | `pmtiles extract` (below) |
| `style.json`, `fonts/`, `sprites/` | map style (Protomaps "light" + our layers), fonts and icons | `tools/style/make_style.mjs`, protomaps/basemaps-assets |
| `malta-depth.bin` / `.json` | depth grid (~38 m) for depth lookups | `tools/make_data.py` |
| `malta-contours.geojson` | depth contours 5–200 m | `tools/make_data.py` |
| `malta-extras.geojson` | our extra map lines (tunnels) | `tools/make_data.py` from `enrichment/map.geojson` |

### The data and its limits

- **Dive sites**: the files in `sites/`. They were made from OSM: sites tagged as dive sites plus
  those named as one ("... (Dive Site)") but tagged as a reef or statue, without dive centres, shops
  and clubs (rules in `tools/osm_rules.py`, also used by the Garmin map), with duplicates merged and
  "(Dive Site)" dropped from names. Most have researched level, depths, entry, conditions,
  descriptions and sources (mainly from maltadives.com and the Calypso Sub-Aqua Club site guides,
  descriptions in our own words). `tools/import_sites.py` adds new OSM sites as new files.
- **Depths**: the EMODnet Bathymetry DTM (115 m cells) resampled to ~38 m, with land and sea from
  the OSM coastline. EMODnet's own coastline is only as precise as its cells, so along the coast,
  where OSM says sea but EMODnet says land, there is no depth (contours stop, lookups say "no data").
  The grid shows the shape of the seabed, not individual rocks, and on steep slopes it can be off by
  tens of metres (about 23 m at MV Xlendi, which lies at 44 m). Don't plan dives on it alone.
- **Our additions** in `enrichment/` (see its README): areas with a known depth (the Inland Sea at
  2 m), measured depths (Xlendi Bay, from the bay's information board) and extra map lines (the
  Inland Sea tunnel).

## Regenerating

From the repo root:

```bash
python3 shared/tools/import_sites.py   # new OSM dive sites -> new files in shared/sites/
python3 shared/tools/make_data.py      # depth grid, contours, extras -> shared/data/
pmtiles extract https://build.protomaps.com/YYYYMMDD.pmtiles shared/data/malta.pmtiles \
  --bbox=14.10,35.75,14.65,36.12 --maxzoom=15
(cd shared/tools/style && npm install && node make_style.mjs ../../data/style.json)
swift shared/tools/make_icon.swift ios/DiveMalta/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

- `make_data.py` and `import_sites.py` only need the Python standard library. They download the OSM
  dive sites, the OSM places named as dive sites, the OSM coastline (all via Overpass) and the
  EMODnet depth grid, and cache them in `tools/cache/` (not in git); delete that folder to download them again. Change the
  bounding box and `LEVELS` there for another area or other depths.
- `malta.pmtiles` comes from the Protomaps daily build (`brew install pmtiles`; pick a date from
  build.protomaps.com). The style is generated from `@protomaps/basemaps` with our contour,
  tunnel and dive-site layers added.
- The icon is the dive flag with the George Cross from the Maltese flag; the same 1024 px PNG works
  for an Android launcher icon.

## Licences

Map data © OpenStreetMap contributors (ODbL), map tiles by Protomaps. Bathymetry © EMODnet Bathymetry
Consortium (CC BY 4.0). Map style: Protomaps Basemaps (BSD-3-Clause). Fonts: Noto Sans (SIL OFL).
Map icons: derived from tangrams/icons (MIT). The apps must show these credits and include the
licence texts (the iOS app does so in its About screen).
