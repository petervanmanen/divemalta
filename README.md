# Dive Malta

Dive sites of Malta, Gozo and Comino with depth contours, on a map that works offline — as an iPhone
app, a Garmin watch map, and (later) an Android app. All of them are built from the same data.

```
shared/     data and tools all apps use
  enrichment/   our own additions: researched site info, known depths, tunnels
  tools/        make_data.py (sites, depth grid, contours), osm_rules.py, map style, icon generator
  data/         the generated data the apps bundle: map tiles, style, fonts, contours, sites, depths
ios/        iPhone/iPad app (SwiftUI + MapLibre), screenshots, TestFlight export settings
android/    Android app (not started yet)
garmin/     transparent Garmin watch map of the dive sites of Europe (mkgmap)
```

- [shared/README.md](shared/README.md): where the data comes from, how to regenerate it, licences
- [shared/enrichment/README.md](shared/enrichment/README.md): how to add or correct sites, depths and tunnels
- [ios/README.md](ios/README.md): building, screenshots, TestFlight
- [garmin/README.md](garmin/README.md): the Garmin map
- [PRIVACY.md](PRIVACY.md): privacy policy of the apps

`.github/workflows/testflight.yml` builds the iOS app and uploads it to TestFlight (see the iOS README).

Map data © OpenStreetMap contributors (ODbL), map tiles by Protomaps. Bathymetry © EMODnet Bathymetry
Consortium (CC BY 4.0).
