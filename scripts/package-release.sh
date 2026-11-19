#!/bin/bash
# Builds a universal release and packages it as dist/Keylume-<version>.zip
# (app + CLI + README) with a SHA-256 checksum file.
#
#   VERSION=0.1.0 ./scripts/package-release.sh
#
# Notarization runs when SIGN_IDENTITY is a Developer ID and these are set:
#   NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD (an app-specific password)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${VERSION:?Set VERSION, e.g. VERSION=0.1.0}"
export VERSION UNIVERSAL=1
./scripts/make-app.sh

STAGE=$(mktemp -d)/Keylume-$VERSION
mkdir -p "$STAGE"
ditto dist/Keylume.app "$STAGE/Keylume.app"
cp dist/keylume "$STAGE/keylume"
cp README.md LICENSE "$STAGE/"

ZIP="dist/Keylume-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$STAGE" "$ZIP"

if [ -n "${SIGN_IDENTITY:-}" ] && [ -n "${NOTARY_APPLE_ID:-}" ]; then
  xcrun notarytool submit "$ZIP" --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD" --wait
  # Staple the ticket to the app, then re-zip so the download carries it.
  xcrun stapler staple "$STAGE/Keylume.app"
  rm -f "$ZIP"
  ditto -c -k --norsrc --noextattr --noacl --keepParent "$STAGE" "$ZIP"
fi

rm -rf "$(dirname "$STAGE")"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
echo "Packaged $ZIP"
cat "$ZIP.sha256"
