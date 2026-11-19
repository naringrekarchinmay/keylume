#!/bin/bash
# Builds Keylume.app and the keylume CLI into ./dist.
#
# Environment (all optional):
#   VERSION        marketing version, e.g. 0.2.0 (default: 0.1.0-dev)
#   BUILD_NUMBER   CFBundleVersion (default: 1)
#   UNIVERSAL=1    build for Apple silicon and Intel in one binary
#   SIGN_IDENTITY  e.g. "Developer ID Application: Name (TEAMID)"; ad-hoc if unset
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_ID="io.github.naringrekarchinmay.keylume"

if [ "${UNIVERSAL:-0}" = "1" ]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
else
  ARCH_FLAGS=()
fi

swift build -c release "${ARCH_FLAGS[@]}" --product KeylumeApp
swift build -c release "${ARCH_FLAGS[@]}" --product keylume
# The output folder differs between Swift versions for multi-arch builds; ask SwiftPM.
OUT=$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)

APP=dist/Keylume.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$OUT/KeylumeApp" "$APP/Contents/MacOS/Keylume"
cp "$OUT/keylume" dist/keylume

# App icon: build an .icns from the 1024 px master (redraw it with scripts/draw-icon.swift).
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) assets/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Keylume</string>
  <key>CFBundleDisplayName</key><string>Keylume</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>Keylume</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>MIT License. Not affiliated with Royal Kludge.</string>
</dict>
</plist>
PLIST

if [ -n "${SIGN_IDENTITY:-}" ]; then
  # Developer ID: hardened runtime + timestamp, as notarization requires.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" dist/keylume
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  # Ad-hoc signature with an identifier-based designated requirement, so macOS
  # keeps the Input Monitoring grant across rebuilds.
  codesign --force --sign - dist/keylume
  codesign --force --sign - \
    --requirements "=designated => identifier \"${BUNDLE_ID}\"" "$APP"
fi
echo "Built $APP and dist/keylume (version $VERSION)"
