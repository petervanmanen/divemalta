# Our additions to the map and depth data

`tools/make_data.py` merges these files over the downloaded data. (The dive sites themselves are
in `../sites/`, one file each.) Edit them, run
`python3 tools/make_data.py` and rebuild the app. Every entry can have a `note` saying where it
comes from; the app ignores it.

- **depths.geojson**: polygons with a known depth (`depth_m`, positive). The depth grid is set to that
  depth inside the polygon, also where OSM or EMODnet says land; depth lookups use it and contours
  follow it.
- **map.geojson**: extra lines drawn on the map. `kind: "tunnel"` is a dashed blue line with its
  `name` along it.
