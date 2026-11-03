#!/bin/sh
# Assembles Chronobar.app from a release build and ad-hoc signs it.
# Needs only the Command Line Tools; Xcode is not required.
#
#   scripts/bundle-app.sh [output-dir]      (default: build)
#
# VERSION sets the bundle version (default 0.1.0). SWIFT_BUILD_FLAGS is passed to
# `swift build`, e.g. SWIFT_BUILD_FLAGS=--disable-sandbox inside a Homebrew build.
set -eu

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
OUT="${1:-build}"
APP="$OUT/Chronobar.app"

# shellcheck disable=SC2086
swift build -c release --product Chronobar ${SWIFT_BUILD_FLAGS:-}
# shellcheck disable=SC2086
BIN="$(swift build -c release --show-bin-path ${SWIFT_BUILD_FLAGS:-})"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Chronobar" "$APP/Contents/MacOS/Chronobar"

# SwiftPM resource bundles (from dependencies with resources) go where Bundle.module looks for them.
for bundle in "$BIN"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Chronobar</string>
    <key>CFBundleExecutable</key>
    <string>Chronobar</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.nhall.chronobar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Chronobar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Nick Hall. MIT License.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "$APP"
