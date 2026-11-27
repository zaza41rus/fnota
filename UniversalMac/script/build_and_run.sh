#!/bin/bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT_DIR/dist.noindex/fnota.app"
BUILD_DIR="$(mktemp -d /tmp/fnota-build.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT
xcodebuild -project "$ROOT_DIR/UniversalMac.xcodeproj" -scheme UniversalMac -configuration Debug -derivedDataPath "$BUILD_DIR" build > "$ROOT_DIR/build.log" 2>&1 || { tail -70 "$ROOT_DIR/build.log"; exit 1; }
mkdir -p "$ROOT_DIR/dist.noindex"
rm -rf "$APP"
ditto "$BUILD_DIR/Build/Products/Debug/fnota.app" "$APP"
mkdir -p "$APP/Contents/Frameworks" "$APP/Contents/Resources"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
cp "$ROOT_DIR"/Vendor/sherpa-onnx-gigaam-preview-osx-arm64/lib/{libsherpa-onnx-c-api.dylib,libonnxruntime.dylib} "$APP/Contents/Frameworks/"
cp "$ROOT_DIR/Vendor/native-libs/libctranslate2.4.8.3.dylib" "$APP/Contents/Frameworks/"
CTRANSLATE_ID="$(otool -D "$APP/Contents/Frameworks/libctranslate2.4.8.3.dylib" | sed -n '2p')"
install_name_tool -id @rpath/libctranslate2.4.8.3.dylib "$APP/Contents/Frameworks/libctranslate2.4.8.3.dylib"
if [[ "$CTRANSLATE_ID" != @rpath/libctranslate2.4.8.3.dylib ]]; then
  install_name_tool -change "$CTRANSLATE_ID" @rpath/libctranslate2.4.8.3.dylib "$APP/Contents/MacOS/UniversalMac"
fi
cp -R "$ROOT_DIR/Resources/." "$APP/Contents/Resources/"
ICON_OUTPUT="$(mktemp -d /tmp/fnota-app-icon.XXXXXX)"
xcrun actool --compile "$ICON_OUTPUT" --app-icon AppIcon --platform macosx \
  --minimum-deployment-target 27.0 --target-device mac \
  --output-partial-info-plist "$ICON_OUTPUT/Info.plist" "$ROOT_DIR/AppIcon.icon"
cp "$ICON_OUTPUT/Assets.car" "$ICON_OUTPUT/AppIcon.icns" "$APP/Contents/Resources/"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist"
rm -r "$ICON_OUTPUT"
swiftc -O "$ROOT_DIR/Helper/LeasePolicy.swift" "$ROOT_DIR/Helper/main.swift" -o "$APP/Contents/Resources/fnota-lid-helper"
codesign --force --sign - --identifier local.fnota.lid "$APP/Contents/Resources/fnota-lid-helper"
# Models are managed in Application Support and downloaded through Settings.
rm -rf "$APP/Contents/Resources/Models"
for lib in "$APP/Contents/Frameworks/"*.dylib; do codesign --force --sign - "$lib"; done
codesign --force --sign - --requirements '=designated => identifier "local.safarilocalru.UniversalMac"' --identifier local.safarilocalru.UniversalMac "$APP"
if [[ "$MODE" != --build-only ]]; then
  pkill -x UniversalMac >/dev/null 2>&1 || true
fi
case "$MODE" in
 --build-only) echo "$APP" ;;
 --debug) lldb -- "$APP/Contents/MacOS/UniversalMac" ;;
 --logs|--telemetry) open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'process == "UniversalMac"' ;;
 --verify) open -n "$APP"; sleep 1; pgrep -x UniversalMac >/dev/null ;;
 run) open -n "$APP" ;;
 *) echo 'Usage: build_and_run.sh [--build-only|--debug|--logs|--telemetry|--verify]'; exit 2 ;;
esac
