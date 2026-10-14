#!/bin/bash
# App Store screenshots of Dive Malta, taken in the iOS simulator.
#
#   tools/screenshots.sh                      # default devices (see below)
#   tools/screenshots.sh "iPhone 18 Pro Max"  # one or more simulator names
#
# Output: screenshots/<device>/<n>-<scene>.jpg at the device's native resolution, without alpha
# channel (App Store Connect rejects transparency), checked against the accepted sizes below.
# The app is started with `-screenshot <scene>` (DiveMalta/ScreenshotMode.swift), which opens it in a
# fixed state; the status bar is set to 9:41 with full battery and signal.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# 6.3" iPhone (required), 6.9" iPhone (recommended, otherwise App Store Connect scales the 6.5")
# and 13" iPad (required because the app also runs on iPad).
DEVICES=("$@")
[ ${#DEVICES[@]} -eq 0 ] && DEVICES=("iPhone 18 Pro" "iPhone 18 Pro Max" "iPad Pro 13-inch (M5)")

# Portrait sizes App Store Connect accepts (developer.apple.com › Screenshot specifications).
ACCEPTED="1179x2556 1206x2622 1260x2736 1290x2796 1320x2868 1242x2688 1284x2778 2048x2732 2064x2752"

# Order = order in the App Store.
SCENES=(splash map contours site depth list)
BUNDLE_ID=nl.petervanmanen.DiveMalta
WAIT=${WAIT:-7}   # seconds for the app to start and the map to draw

echo "Building…"
xcodebuild -project DiveMalta.xcodeproj -scheme DiveMalta -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/Screenshots \
  build -quiet
APP=build/Screenshots/Build/Products/Debug-iphonesimulator/DiveMalta.app

udid_for() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name:
            print(d["udid"]); sys.exit()
sys.exit(f"No simulator named {name!r}; see: xcrun simctl list devices available")' "$1"
}

for DEVICE in "${DEVICES[@]}"; do
  UDID=$(udid_for "$DEVICE")
  OUT="screenshots/$(echo "$DEVICE" | tr ' ()"' '-' | tr -s '-' | sed 's/-$//')"
  mkdir -p "$OUT"
  rm -f "$OUT"/*.png "$OUT"/*.jpg
  echo "== $DEVICE ($UDID) -> $OUT"

  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl ui "$UDID" appearance light
  xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  xcrun simctl install "$UDID" "$APP"

  n=1
  for SCENE in "${SCENES[@]}"; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshot "$SCENE" >/dev/null
    # The simulator sometimes starts the app in the background; launching the running app again
    # brings it to the front (it keeps its state and launch arguments).
    sleep 2
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshot "$SCENE" >/dev/null
    sleep "$WAIT"
    RAW="$OUT/.raw.png"
    FILE="$OUT/$n-$SCENE.jpg"
    xcrun simctl io "$UDID" screenshot --type=png "$RAW" >/dev/null 2>&1
    # JPEG has no alpha channel; quality 95 keeps text sharp.
    sips -s format jpeg -s formatOptions 95 "$RAW" --out "$FILE" >/dev/null
    rm -f "$RAW"
    SIZE=$(sips -g pixelWidth -g pixelHeight "$FILE" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')
    ALPHA=$(sips -g hasAlpha "$FILE" | awk '/hasAlpha/ {print $2}')
    case " $ACCEPTED " in *" $SIZE "*) OK="ok" ;; *) OK="NOT an App Store size" ;; esac
    echo "   $FILE  $SIZE  alpha=$ALPHA  $OK"
    n=$((n + 1))
  done

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl status_bar "$UDID" clear
done

echo "Done. Upload these in App Store Connect › your app › the version › Previews and Screenshots."
