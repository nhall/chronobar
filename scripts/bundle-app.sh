#!/bin/sh
# Assembles Chronobar.app from a release build and ad-hoc signs it.
# Needs only the Command Line Tools; Xcode is not required.
#
#   scripts/bundle-app.sh [--dev] [output-dir]      (default: build)
#
# --dev builds "Chronobar Dev.app" instead: a development copy that runs next to the everyday one
# without sharing anything with it. It has its own bundle ID (io.github.nhall.chronobar.dev), so its
# own settings, Selected Project, heartbeat and login item; its own data folder
# (~/Library/Application Support/Chronobar Dev); its own executable name (ChronobarDev, for
# `killall`); and a DEV badge on its Dock icon.
#
# VERSION sets the bundle version (default 0.1.0). SWIFT_BUILD_FLAGS is passed to
# `swift build`, e.g. SWIFT_BUILD_FLAGS=--disable-sandbox inside a Homebrew build.
set -eu

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"

DEV=0
if [ "${1:-}" = "--dev" ]; then
    DEV=1
    shift
fi
OUT="${1:-build}"

if [ "$DEV" = 1 ]; then
    NAME="Chronobar Dev"
    EXECUTABLE="ChronobarDev"
    BUNDLE_ID="io.github.nhall.chronobar.dev"
    # Read by BuildVariant in ChronobarCore.
    VARIANT_KEYS="    <key>ChronobarDataFolder</key>
    <string>Chronobar Dev</string>
    <key>ChronobarDockBadge</key>
    <string>DEV</string>
"
else
    NAME="Chronobar"
    EXECUTABLE="Chronobar"
    BUNDLE_ID="io.github.nhall.chronobar"
    VARIANT_KEYS=""
fi
APP="$OUT/$NAME.app"

# shellcheck disable=SC2086
swift build -c release --product Chronobar ${SWIFT_BUILD_FLAGS:-}
# shellcheck disable=SC2086
BIN="$(swift build -c release --show-bin-path ${SWIFT_BUILD_FLAGS:-})"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Chronobar" "$APP/Contents/MacOS/$EXECUTABLE"

# SwiftPM resource bundles (from dependencies with resources) go where Bundle.module looks for them.
for bundle in "$BIN"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

# App icon, from the committed PNGs. scripts/make-icon.swift regenerates them.
iconutil --convert icns --output "$APP/Contents/Resources/Chronobar.icns" packaging/icon/AppIcon.iconset

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>Chronobar</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
${VARIANT_KEYS}    <key>LSApplicationCategoryType</key>
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
