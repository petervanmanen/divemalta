# Dive Malta (iOS)

An iPhone app with the OpenStreetMap dive sites around Malta, Gozo and Comino, depth contours from
[EMODnet Bathymetry](https://emodnet.ec.europa.eu/en/bathymetry), and an OpenStreetMap map that is
bundled with the app, so everything works offline.

- **Map**: OpenStreetMap data for Malta as vector tiles (`malta.pmtiles`, an extract of the
  [Protomaps](https://protomaps.com) daily build), drawn with [MapLibre](https://maplibre.org) in the
  Protomaps "light" style. Always north up, no tilting. When you pan away from Malta a message says the app only has Malta, with a button to go back;
  the location button only follows you inside Malta and otherwise shows a short message.
- **Dive sites**: 68 sites from OSM: those tagged as dive sites plus those named as one ("... (Dive
  Site)") but tagged as a reef or statue. Dive centres, shops and clubs are left out; a site mapped
  twice (same or alternative name, close together) is merged into one. "(Dive Site)" and similar are dropped from the
  names, and a place known to be a dive site (by its name or listed in `enrichment/`) isn't shown as a
  reef just because OSM tags it `natural=reef`. Wrecks are purple, caves
  brown; nearby sites are grouped until you zoom in. Tap one for its depth, type, entry, description,
  website, all OSM tags, the seabed depth there and directions in Apple Maps. The list button searches
  all sites.
- **Depth contours**: 5, 10, 15, 20, 30, 40, 50, 60, 80, 100, 150 and 200 m, labelled along the lines.
  The contour button switches them off.
- **Depth anywhere**: touch and hold the sea to look up the depth at that point.
- **Our additions**: extra sites, known depths and tunnels from `enrichment/` (see below).

Contours and depth lookups come from one depth grid bundled in the app: the EMODnet Bathymetry DTM
(115 m cells) resampled to ~38 m, with land and sea taken from the OpenStreetMap coastline. EMODnet's
own coastline is only as precise as its 115 m cells, so it has land in the sea in places (around
MV Xlendi it puts the wreck itself on land) and sea on land in others. Along the coast, where OSM says
sea but EMODnet says land, there is no depth: contours stop there and a depth lookup says "no data".

The grid shows the shape of the seabed, not individual rocks, and on steep slopes it can be off by
tens of metres at a given spot (it gives about 23 m at MV Xlendi, which lies at 44 m). Don't plan
dives on it alone.

## Our own additions

`enrichment/` holds what we add on top of OSM and EMODnet (see its README): extra or corrected dive
sites (`sites.json`), areas with a known depth (`depths.geojson`) and extra map lines such as tunnels
(`map.geojson`). `tools/make_data.py` merges them in. Most sites have researched information (level, typical and maximum depth, shore or boat entry,
conditions, a description and sources), mainly from maltadives.com and the Calypso Sub-Aqua Club
site guides. So far: the name and description of the Inland
Sea dive site at Dwejra, the Inland Sea at 2 m, and the tunnel from the Inland Sea to the open sea
(in OSM, but not drawn by the basemap).

## Running

Open `DiveMalta.xcodeproj` in Xcode and run on a simulator or your iPhone (team 9XCZUWMGXB,
bundle id `nl.petervanmanen.DiveMalta`). Everything the app needs is in the repo, so no data steps are
needed just to build it.

## App Store screenshots

```bash
tools/screenshots.sh                       # 6.9" iPhone and 13" iPad (the sizes App Store Connect requires)
tools/screenshots.sh "iPhone 18 Pro Max"   # or any simulators by name
```

The script builds the app, boots each simulator, sets the status bar to 9:41 with full battery, and
starts the app with `-screenshot <scene>` (see `DiveMalta/ScreenshotMode.swift`) for six fixed scenes:
opening screen, map of Malta, contours around Comino, a site page (Um El Faroud), a depth lookup and
the site list. The PNGs land in `screenshots/<device>/` (not in git) at the device's native size.
Set `WAIT=10` if the map hasn't finished drawing in a shot.

## Data

```bash
python3 tools/make_data.py    # Malta sites, depth grid and contours -> DiveMalta/Data/ and MaltaMap.bundle/
pmtiles extract https://build.protomaps.com/YYYYMMDD.pmtiles DiveMalta/MaltaMap.bundle/malta.pmtiles \
  --bbox=14.10,35.75,14.65,36.12 --maxzoom=15
(cd tools/style && npm install && node make_style.mjs ../../DiveMalta/MaltaMap.bundle/style.json)
swift tools/make_icon.swift DiveMalta/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

- `make_data.py` only needs the Python standard library (tag rules in `tools/osm_rules.py`). It
  downloads the OSM dive sites, the OSM places named as dive sites, the OSM coastline (all via
  Overpass) and the EMODnet depth grid, and caches them in `tools/cache/`; delete that folder to
  download them again. Change the bounding box and `LEVELS` there for another area or other depths.
- `malta.pmtiles` (8 MB) comes from the Protomaps daily build (`brew install pmtiles`; pick a date from
  build.protomaps.com). The map style is generated by `tools/style/make_style.mjs` from
  `@protomaps/basemaps`, with the contour and dive-site layers added; fonts and sprites in
  `MaltaMap.bundle` are from [protomaps/basemaps-assets](https://github.com/protomaps/basemaps-assets).
  `MaltaMap.bundle` is copied into the app as one folder; the app points the style at it when it starts.
- The icon is the dive flag with the George Cross from the Maltese flag, drawn by `tools/make_icon.swift`.

Opening screen photo: [Blue Hole, Gozo](https://commons.wikimedia.org/wiki/File:Agujero_Azul,_isla_de_Gozo,_Malta,_2021-08-22,_DD_71.jpg)
by Diego Delso (delso.photo), licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/);
resized for the app (`DiveMalta/Assets.xcassets/Splash.imageset/BlueHole.jpg`), and that resized
copy is under the same licence. The credit is shown on the opening screen.

Map data © OpenStreetMap contributors (ODbL), map tiles by Protomaps. Bathymetry © EMODnet Bathymetry
Consortium (CC BY 4.0).
