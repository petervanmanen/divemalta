# Dive Malta for iOS

An iPhone app with the OpenStreetMap dive sites around Malta, Gozo and Comino, depth contours from
[EMODnet Bathymetry](https://emodnet.ec.europa.eu/en/bathymetry), and an OpenStreetMap map that is
bundled with the app, so everything works offline.

- **Map**: OpenStreetMap data for Malta as vector tiles (`malta.pmtiles`, an extract of the
  [Protomaps](https://protomaps.com) daily build), drawn with [MapLibre](https://maplibre.org) in the
  Protomaps "light" style. Always north up, no tilting. When you pan away from Malta a message says the app only has Malta, with a button to go back;
  the location button only follows you inside Malta and otherwise shows a short message.
- **Dive sites**: the 67 sites in `../shared/sites/` (one JSON file each, see its README). Wrecks are
  purple, caves brown; nearby sites are grouped until you zoom in. Tap one for its depth, type,
  entry, level, description, conditions, sources, the seabed depth there and directions in Apple
  Maps. The list button searches all sites.
- **Depth contours**: 5, 10, 15, 20, 30, 40, 50, 60, 80, 100, 150 and 200 m, labelled along the lines.
  The contour button switches them off.
- **Depth anywhere**: touch and hold the sea to look up the depth at that point.
- **Our additions**: known depths and tunnels from `../shared/enrichment/`.

Where the data comes from and how good it is: [../shared/README.md](../shared/README.md).

## Running

Open `DiveMalta.xcodeproj` in Xcode and run on a simulator or your iPhone (team 9XCZUWMGXB,
bundle id `nl.petervanmanen.DiveMalta`). The app bundles `../shared/data/` as a folder (`data/` in the
app), and the build phase "Gather dive sites" adds the sites from `../shared/sites/` to it
(`shared/tools/gather_sites.py`, needs `python3`). Everything it needs is in the repo, so no data
steps are needed just to build it.

## TestFlight from GitHub

`.github/workflows/testflight.yml` (at the repo root) archives the app on a GitHub macOS runner and uploads it to App
Store Connect (then it shows up in TestFlight). It runs when you push a tag like `v1.0.1`
(`git tag v1.0.1 && git push origin v1.0.1`) or by hand under Actions › TestFlight › Run workflow.
App Store Connect picks the build number (`ios/ExportOptions.plist`), so runs never clash with each
other or with uploads from Xcode. Raise `MARKETING_VERSION` in the project for a new version.

One-time setup:

1. The app must already exist in App Store Connect (bundle id `nl.petervanmanen.DiveMalta`).
2. In App Store Connect › Users and Access › Integrations › App Store Connect API › Team Keys, create
   a key with the **Admin** role (it needs to manage certificates and profiles for signing).
   Download the `.p8` file (only possible once) and note the Key ID and the Issuer ID.
3. Add the repository secrets:
   ```bash
   gh secret set ASC_KEY_ID --repo petervanmanen/divemalta
   gh secret set ASC_ISSUER_ID --repo petervanmanen/divemalta
   gh secret set ASC_PRIVATE_KEY --repo petervanmanen/divemalta < AuthKey_XXXXXXXXXX.p8
   ```
   Keep the `.p8` file somewhere safe and out of the repo.

## App Store screenshots

```bash
ios/tools/screenshots.sh                   # 6.3" and 6.9" iPhone and 13" iPad
ios/tools/screenshots.sh "iPhone 18 Pro Max"  # or any simulators by name
```

The script builds the app, boots each simulator, sets the status bar to 9:41 with full battery, and
starts the app with `-screenshot <scene>` (see `DiveMalta/ScreenshotMode.swift`) for six fixed scenes:
opening screen, map of Malta, contours around Comino, a site page (Um El Faroud), a depth lookup and
the site list. The JPEGs land in `ios/screenshots/<device>/` (not in git) at the device's native size, without alpha
channel, and the script checks each size against the sizes App Store Connect accepts. The 6.3"
iPhone and the 13" iPad are required; the 6.9" iPhone is recommended.
Set `WAIT=10` if the map hasn't finished drawing in a shot.

## Promotional images

`ios/tools/screenshots.sh` makes these at the end (set `PROMO=0` to skip); to make only these:

```bash
swift ios/tools/make_promo.swift   # needs the 6.9" iPhone screenshots
```

Makes PNGs in `ios/promo/` (not in git), sized per App Store Connect's creative assets
specifications: `universal-5244x2950` (16:9, for both the product page header and search results),
`header-3840x1646` (21:9, product page header) and `search-3840x2560` (3:2, search results). Each
shows the opening-screen photo with icon, name and tagline, and the 6.9" iPhone contours screenshot.

## Credits

Opening screen photo (`ios/DiveMalta/Assets.xcassets/Splash.imageset/Splash.jpg`): sunset over the cliffs of
Gozo, by the app's author; all rights reserved, not covered by the repo's other licences.

Map data, bathymetry and open-source licences: see [../shared/README.md](../shared/README.md) and the
About screen in the app.
