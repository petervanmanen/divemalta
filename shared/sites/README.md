# Dive sites

One JSON file per dive site. These files are the content of the apps: both apps gather every
`*.json` in this folder while building (`../tools/gather_sites.py`, run by an Xcode build phase and a
Gradle task). To add, change or remove a site, add, edit or delete its file and rebuild. Files
starting with `_` are skipped.

## Fields

| Field | Required | Shown in the app as | Example |
|---|---|---|---|
| `id` | yes | (link to OpenStreetMap when it is an OSM id) | `"node/663869707"`, or `"custom/my-site"` for a site that isn't in OSM |
| `name` | yes | name | `"Um El Faroud"` |
| `lat`, `lon` | yes | position on the map (must be around Malta, Gozo or Comino) | `35.81758`, `14.44956` |
| `type` | | type and map colour (wreck purple, cave brown) | `wreck`, `cave`, `reef`, `statue`, `wall`, `rocks`, … |
| `maxDepth` | | max depth | `"36m"`, `"30m+"` |
| `typicalDepth` | | typical depth | `"20m"` |
| `level` | | level | `"Advanced (Advanced Open Water)"` — Beginner / Advanced / Experienced / Technical |
| `entry` | | entry | `"shore"` or `"boat"` |
| `shoreAccess` | | entry, e.g. "Shore (easy)" | `"Easy"`, `"Medium"`, `"Hard"` |
| `difficulty` | | difficulty | as in OSM |
| `description` | | description | in our own words |
| `conditions` | | conditions | wind, currents, tips |
| `website` | | website link | `"https://…"` |
| `sources` | | sources (links) | `["https://…", "https://…"]` |
| `note` | | — (not bundled) | where the information comes from, how sure a match is |
| `osm` | | — (not bundled) | `{"ids": [...], "tags": {...}}`: the OSM entries this site was made from (including merged duplicates) and their original tags |

A broken file (invalid JSON, a missing required field, an unknown field, an unknown `type` or
`entry`, a position outside the map, or an id used twice) stops the build with the file name and the
problem. Check the whole folder without building:

```bash
python3 shared/tools/gather_sites.py shared/sites /tmp/sites-check
```

## New sites from OpenStreetMap

```bash
python3 shared/tools/import_sites.py            # or --refresh to download the OSM data again
```

adds a file for every OSM dive site that isn't here yet. Existing files are never changed. An OSM
entry is skipped when its id is a site's `id` or in its `osm.ids`, or listed in `_ignored.json`
(entries that aren't dive sites, like an information board).
