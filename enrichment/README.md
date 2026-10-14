# Our additions to the OSM and EMODnet data

`tools/make_data.py` merges these files over the downloaded data. Edit them, run
`python3 tools/make_data.py` and rebuild the app. Every entry can have a `note` saying where it
comes from; the app ignores it.

- **sites.json**: dive sites to add or correct. An entry whose `id` matches an OSM site (e.g.
  `node/123`) updates it: `name`, `lat`/`lon`, `maxDepth` (e.g. `"30m"`), `type` (`wreck`, `cave`,
  `reef`, ...), `entry` (`shore`, `boat`) replace the OSM values, and `tags` are merged over the OSM
  tags (`description` shows on the site page). Any other entry is a new site and needs `id`, `name`,
  `lat` and `lon`; use an id like `node/123` when the place exists in OSM (the app links to it), or
  `custom/<something>` otherwise. `"remove": true` drops a site.
  Researched information goes in these tags, shown on the site page:
  `description` (in our own words), `dive:level` (Beginner / Advanced / Experienced / Technical,
  with the certification in brackets), `dive:depth_avg` (typical depth), `dive:shore_access` (Easy /
  Medium / Hard, for shore dives), `dive:conditions` (wind, currents, tips) and `dive:sources`
  (URLs separated by spaces). Use `note` for how sure a match is.
- **depths.geojson**: polygons with a known depth (`depth_m`, positive). The depth grid is set to that
  depth inside the polygon, also where OSM or EMODnet says land; depth lookups use it and contours
  follow it.
- **map.geojson**: extra lines drawn on the map. `kind: "tunnel"` is a dashed blue line with its
  `name` along it.
