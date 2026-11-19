#!/bin/bash
# Builds Keylume.app and the keylume CLI into ./dist.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product KeylumeApp
swift build -c release --product keylume

APP=dist/Keylume.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KeylumeApp "$APP/Contents/MacOS/Keylume"
cp .build/release/keylume dist/keylume

# App icon: build an .icns from the 1024 px master (redraw it with scripts/draw-icon.swift).
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) assets/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Keylume</string>
  <key>CFBundleDisplayName</key><string>Keylume</string>
  <key>CFBundleIdentifier</key><string>io.github.naringrekarchinmay.keylume</string>
  <key>CFBundleExecutable</key><string>Keylume</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

# Ad-hoc signature with an identifier-based designated requirement, so macOS
# keeps the Input Monitoring grant across rebuilds. Set SIGN_IDENTITY to use a
# real certificate (e.g. "Developer ID Application: ...") for releases.
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - \
    --requirements '=designated => identifier "io.github.naringrekarchinmay.keylume"' "$APP"
fi
codesign --force --sign - dist/keylume
echo "Built $APP and dist/keylume"
