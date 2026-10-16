# Our additions to the map and depth data

`tools/make_data.py` merges these files over the downloaded data. (The dive sites themselves are
in `../sites/`, one file each.) Edit them, run
`python3 tools/make_data.py` and rebuild the app. Every entry can have a `note` saying where it
comes from; the app ignores it.

- **depths.geojson**: polygons with a known depth (`depth_m`, positive). The depth grid is set to that
  depth inside the polygon, also where OSM or EMODnet says land; depth lookups use it and contours
  follow it.
- **soundings.geojson**: measured depths as points (`depth_m`, positive), e.g. copied from a bay's
  information board. Near the soundings the depth grid uses their inverse-distance-weighted average,
  fading back into EMODnet between 40 and 160 m from the nearest sounding; the grid cell a sounding lies
  in gets that exact depth (the shallowest, if several fall in one cell), so small reefs survive; short
  contour rings near soundings are kept. OSM land stays land. So far: Xlendi Bay, from the bay's
  information board (Ministry for Gozo / MTA), lined up with the OSM coastline and the reef's cardinal
  beacon (positions accurate to about 20–30 m); the reef at the entrance is set to 1 m, as the board's
  text says its top is less than 1 m deep.
- **map.geojson**: extra lines drawn on the map. `kind: "tunnel"` is a dashed blue line with its
  `name` along it.
