#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ARCHS="${DSH_ISLAND_ARCHS:-arm64 x86_64}"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/DSH Island.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$PROJECT_ROOT/Resources/Info.plist"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
ZIP_FILENAME="DSH-Island-$VERSION-macOS-universal.zip"
ZIP_PATH="$DIST_DIR/$ZIP_FILENAME"
CHECKSUM_PATH="$ZIP_PATH.sha256"

SWIFT_ARGUMENTS=(-c release)
for architecture in $BUILD_ARCHS; do
  SWIFT_ARGUMENTS+=(--arch "$architecture")
done

swift build --package-path "$PROJECT_ROOT" "${SWIFT_ARGUMENTS[@]}"
BIN_DIR="$(swift build --package-path "$PROJECT_ROOT" "${SWIFT_ARGUMENTS[@]}" --show-bin-path)"

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/dsh-island" "$MACOS_DIR/DSH Island"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"

ICON_TEMP="$(mktemp -d)"
trap 'rm -rf "$ICON_TEMP"' EXIT
ICONSET="$ICON_TEMP/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -s format png "$PROJECT_ROOT/Resources/AppIcon.svg" --out "$ICON_TEMP/AppIcon-1024.png" >/dev/null
while read -r filename pixels; do
  sips -z "$pixels" "$pixels" "$ICON_TEMP/AppIcon-1024.png" --out "$ICONSET/$filename" >/dev/null
done <<'SIZES'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
SIZES
iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"

codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
(cd "$DIST_DIR" && shasum -a 256 "$ZIP_FILENAME" > "$ZIP_FILENAME.sha256")

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
