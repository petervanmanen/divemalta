#!/bin/bash
# Google Play screenshots of Dive Malta, taken in Android emulators.
#
#   android/tools/screenshots.sh            # phone and tablet
#   android/tools/screenshots.sh phone      # one of them
#
# Google Play wants JPEG or 24-bit PNG without alpha, sides 320–3840 px (tablets up to 7680) and the
# long side at most twice the short side; 9:16 is recommended. Most phone emulators are taller than
# 2:1, so this script makes its own emulators with 9:16 screens:
#   phone  : 1080 × 1920  -> play/screenshots/phone/
#   tablet : 1440 × 2560  -> play/screenshots/tablet/
# The app is started with `--es screenshot <scene>` (ScreenshotScene.kt), which opens it in a fixed
# state, and the status bar is put in demo mode (9:41, full battery and signal).
set -euo pipefail

cd "$(dirname "$0")/.."
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
# A private adb server port, so other tools on the Mac that restart the default adb server
# (another adb version, an IDE) can't drop the connection halfway.
export ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT:-5099}
# adb's network (mDNS) and USB discovery can crash its server on recent macOS; emulators don't need them.
export ADB_MDNS=0 ADB_MDNS_OPENSCREEN=0 ADB_LIBUSB=0
ADB="$ANDROID_HOME/platform-tools/adb"
"$ADB" start-server >/dev/null 2>&1
EMULATOR="$ANDROID_HOME/emulator/emulator"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
[ -x "$AVDMANAGER" ] || AVDMANAGER=avdmanager
IMAGE="system-images;android-37.0;google_apis;arm64-v8a"
PACKAGE=nl.petervanmanen.divemalta
SCENES=(splash map contours site depth list)
WAIT=${WAIT:-8}

DEVICES=("$@")
[ ${#DEVICES[@]} -eq 0 ] && DEVICES=(phone tablet)

echo "Building…"
./gradlew -q assembleDebug
APK=app/build/outputs/apk/debug/app-debug.apk

make_avd() {   # name width height density
  local name=$1 config="$HOME/.android/avd/$1.avd/config.ini"
  if [ ! -f "$config" ]; then
    echo no | "$AVDMANAGER" -s create avd -n "$name" -k "$IMAGE" -d pixel_9 --force >/dev/null 2>&1 || true
  fi
  # (Re)apply the screen size every time, in case the AVD already existed.
  python3 - "$config" "$2" "$3" "$4" <<'PY'
import sys
path, w, h, d = sys.argv[1:]
lines = [l for l in open(path) if not l.startswith(("hw.lcd.width", "hw.lcd.height", "hw.lcd.density", "skin.name", "skin.path", "showDeviceFrame"))]
lines += [f"hw.lcd.width={w}\n", f"hw.lcd.height={h}\n", f"hw.lcd.density={d}\n",
          f"skin.name={w}x{h}\n", f"skin.path={w}x{h}\n", "showDeviceFrame=no\n"]
open(path, "w").writelines(lines)
PY
}

for DEVICE in "${DEVICES[@]}"; do
  case "$DEVICE" in
    phone)  AVD=DiveMaltaShotsPhone;  make_avd $AVD 1080 1920 420; PORT=5580 ;;
    tablet) AVD=DiveMaltaShotsTablet; make_avd $AVD 1440 2560 320; PORT=5582 ;;
    *) echo "Unknown device $DEVICE (phone or tablet)"; exit 1 ;;
  esac
  SERIAL=emulator-$PORT
  OUT=play/screenshots/$DEVICE
  mkdir -p "$OUT"; rm -f "$OUT"/*.png "$OUT"/*.jpg
  echo "== $DEVICE ($AVD) -> $OUT"

  # Stop a leftover emulator of an earlier, interrupted run, and always stop ours when the script ends.
  pkill -f -- "-avd $AVD " 2>/dev/null && sleep 5 || true
  "$EMULATOR" -avd $AVD -port $PORT -no-window -no-audio -no-boot-anim -no-snapshot >/dev/null 2>&1 &
  EMU_PID=$!
  trap '"$ADB" -s '$SERIAL' emu kill >/dev/null 2>&1; pkill -f -- "-avd '$AVD' " 2>/dev/null || true' EXIT
  "$ADB" -s $SERIAL wait-for-device
  until [ "$("$ADB" -s $SERIAL shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done

  # Clean status bar.
  "$ADB" -s $SERIAL shell settings put global sysui_demo_allowed 1
  demo() { "$ADB" -s $SERIAL shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
  demo enter
  demo clock -e hhmm 0941
  demo battery -e level 100 -e plugged false
  demo network -e wifi show -e level 4
  demo network -e mobile hide
  demo notifications -e visible false

  # The package manager can lag behind "boot completed"; retry the install a few times.
  for attempt in 1 2 3 4 5 6; do
    "$ADB" -s $SERIAL install -r "$APK" >/dev/null 2>&1 && break
    [ $attempt = 6 ] && { echo "Could not install the app on $SERIAL"; exit 1; }
    sleep 5
  done
  n=1
  for SCENE in "${SCENES[@]}"; do
    # -S stops the app first and -W waits until it has started, so every scene is a fresh launch.
    "$ADB" -s $SERIAL shell am start -S -W -n $PACKAGE/.MainActivity --es screenshot "$SCENE" >/dev/null
    sleep "$WAIT"
    RAW="$OUT/.raw.png"; FILE="$OUT/$n-$SCENE.jpg"
    "$ADB" -s $SERIAL exec-out screencap -p > "$RAW"
    sips -s format jpeg -s formatOptions 95 "$RAW" --out "$FILE" >/dev/null   # JPEG: no alpha
    rm -f "$RAW"
    echo "   $FILE  $(sips -g pixelWidth -g pixelHeight "$FILE" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')"
    n=$((n + 1))
  done

  demo exit
  "$ADB" -s $SERIAL emu kill >/dev/null 2>&1 || true
  wait $EMU_PID 2>/dev/null || true
  trap - EXIT
done

echo "Done. Upload in Play Console › Grow users › Store presence › Main store listing."
