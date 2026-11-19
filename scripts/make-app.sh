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

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Keylume</string>
  <key>CFBundleDisplayName</key><string>Keylume</string>
  <key>CFBundleIdentifier</key><string>io.github.naringrekarchinmay.keylume</string>
  <key>CFBundleExecutable</key><string>Keylume</string>
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
