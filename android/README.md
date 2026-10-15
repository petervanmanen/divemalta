# Dive Malta for Android

The Android version of the app: Kotlin, Jetpack Compose and [MapLibre Native for
Android](https://github.com/maplibre/maplibre-native), with the same features as the iOS app and
built from the same data (`../shared/data`, bundled as `assets/data` by the `copySharedData` Gradle
task). Package name `nl.petervanmanen.divemalta`.

- Map: offline OpenStreetMap vector tiles in the same style as iOS, always north up, no tilting.
  Panning away from Malta shows "Outside the map" with a button back; the location button only
  follows you inside Malta and otherwise shows a short message.
- Dive sites with clusters, a searchable list, and a site page with depth, level, entry,
  conditions, description, sources, the seabed depth and directions.
- Depth contours (button to switch them off) and depth anywhere by touching and holding the sea;
  a tap elsewhere clears it.
- Opening screen with the author's photo; About screen with credits and licences.

## Building

Needs JDK 21 and the Android SDK (`brew install openjdk@21` and `brew install --cask
android-commandlinetools`, then `sdkmanager "platforms;android-37.0" "build-tools;37.0.0"`).
`local.properties` points at the SDK (`sdk.dir=/opt/homebrew/share/android-commandlinetools`).

```bash
cd android
JAVA_HOME=/opt/homebrew/opt/openjdk@21 ./gradlew assembleDebug     # debug APK
JAVA_HOME=/opt/homebrew/opt/openjdk@21 ./gradlew bundleRelease     # signed app bundle for Google Play
```

Release signing reads `android/keystore.properties` (not in git):

```
storeFile=/path/to/upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

## Google Play from GitHub

`.github/workflows/play.yml` builds a signed app bundle on GitHub and uploads it to Google Play. It
runs for tags like `v1.0.1` (the same tags as the TestFlight workflow, so one tag releases both
apps) to the internal testing track, or by hand under Actions › Google Play › Run workflow, where
you choose the track (internal, alpha = closed testing, beta = open testing, production) and
whether the release is rolled out (`completed`) or left as a draft. The versionCode is 100 + the
workflow's run number, so it always goes up; the versionName comes from the tag.

One-time setup:

1. **Upload the first release by hand** in Play Console (e.g. to internal testing): the Play API
   can't create an app's first release. Build it with `./gradlew bundleRelease`.
2. **Service account**: in [Google Cloud Console](https://console.cloud.google.com) create a
   project (or use one), enable the **Google Play Android Developer API**, create a service account
   and a JSON key for it. In Play Console › Users and permissions, invite the service account's
   email and give it access to Dive Malta with the release permissions ("Release to production,
   exclude devices, and use Play App Signing" and "Release apps to testing tracks").
3. **Repository secrets** (run these yourself; they contain your key and passwords):
   ```bash
   base64 -i ~/divemalta-upload.jks | gh secret set ANDROID_KEYSTORE_BASE64 --repo petervanmanen/divemalta
   gh secret set ANDROID_KEYSTORE_PASSWORD --repo petervanmanen/divemalta
   gh secret set ANDROID_KEY_ALIAS --repo petervanmanen/divemalta
   gh secret set ANDROID_KEY_PASSWORD --repo petervanmanen/divemalta
   gh secret set PLAY_SERVICE_ACCOUNT_JSON --repo petervanmanen/divemalta < ~/Downloads/service-account.json
   ```

## Store graphics

`swift android/tools/make_icons.swift` (from the repo root) draws the adaptive launcher icon in
`app/src/main/res/mipmap-*`, the 512 px Play icon and the 1024 × 500 feature graphic in `play/`.
The app also has a screenshot mode (`adb shell am start -n nl.petervanmanen.divemalta/.MainActivity
--es screenshot map`, scenes: splash, map, contours, site, depth, list).
