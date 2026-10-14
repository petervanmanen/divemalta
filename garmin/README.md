# OSM dive sites Europe for Garmin watches

`DiveSitesEurope.img` is a see-through Garmin map with 1,842 dive sites from OpenStreetMap in
Europe. It lies on top of the watch's own map. You need a watch that shows maps
(Descent Mk2/Mk3, Fenix, Epix, Enduro, Forerunner 955/965, …).

- Dive sites are under **Find > Points of Interest > Attractions > Landmark**. They are drawn at every map
  zoom level the map has data for; how far out the watch shows them also depends on its
  **Map detail** setting.
- A watch only shows a point's name, so what OSM knows is added to it: maximum depth, type of site
  and entry, for example "Zeelandbrug (30m)" or "Cala des Tramadiu (18m, boat)". About a third of the
  sites have some of this; the rest show just the name.
- Dive centres, shops and clubs are left out, including those OSM tags as dive sites (by their
  club/shop tags, sports centre or swimming pool tags, or a name like "Tauchbasis" or "Dive Centre").

## Installing

1. Connect the watch with USB. On a Mac most recent watches need an MTP app such as
   [OpenMTP](https://openmtp.ganeshrvel.com) because they don't show up in Finder.
2. Copy `DiveSitesEurope.img` into the `GARMIN` folder on the watch (`Internal Storage/GARMIN`).
   Don't rename it to `gmapsupp.img`, because that would replace any map already called that.
3. Disconnect the watch. Then go to **Settings > Map > Configure maps** (on some models
   **Map > Map Setup**) and switch on **OSM Dive Sites Europe**.

## Rebuilding

```bash
python3 garmin/fetch_europe.py            # worldwide OSM dive sites (cached) -> Europe -> europe-dive-sites.geojson
python3 garmin/fetch_europe.py --refresh  # same, but download the worldwide data again
python3 garmin/build.py                   # build garmin/DiveSitesEurope.img with mkgmap
```

The rules for what counts as a dive site and how depth, type and entry are read from OSM tags are
shared with the apps (`shared/tools/osm_rules.py`). The worldwide download is cached in
`garmin/cache/`; the downloads, `build/`, `tools/` and the built map are not in git.

You need Java (`brew install openjdk`) and mkgmap unpacked in `tools/`
(from https://www.mkgmap.org.uk/download/mkgmap.html). The style in `style/` decides which
Garmin types are used. Names use the Western European character set
(code page 1252) because not every watch can show Unicode maps; mkgmap turns Greek, Turkish and
other letters outside that set into Latin letters.

"Europe" is a hand-drawn outline (see `fetch_europe.py`): Malta, Crete, Cyprus, Turkey, the Canary
Islands, Madeira and the Azores are in; North Africa and the Middle East are out; the eastern edge
is 45°E.

Map data © OpenStreetMap contributors, ODbL.
