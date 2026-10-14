# Dive Malta for Android

Not started yet. The plan is the same app as on iOS, built from the same data:

- Bundle `../shared/data/` as an assets folder and point the map style's `{ASSETS}` at it.
- Draw the map with [MapLibre Native for Android](https://github.com/maplibre/maplibre-native),
  which reads the same `style.json` and `malta.pmtiles`.
- Read `malta-dive-sites.json` and the depth grid (`malta-depth.bin` + `.json`; little-endian Int16
  decimetres, see `shared/tools/make_data.py`) for the site pages and depth lookups.
- Launcher icon: the 1024 px icon from `shared/tools/make_icon.swift`.
