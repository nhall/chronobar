#!/bin/sh
# Prints the Info.plist that scripts/bundle-app.sh puts in Chronobar.app, or with --dev in
# "Chronobar Dev.app". This is the one place the two copies' names, bundle IDs and BuildVariant keys
# are spelled; bundle-app.sh reads the name and executable back from what this prints.
#
#   scripts/info-plist.sh [--dev]
#
# VERSION sets the bundle version (default 0.1.0).
set -eu

VERSION="${VERSION:-0.1.0}"

if [ "${1:-}" = "--dev" ]; then
    NAME="Chronobar Dev"
    EXECUTABLE="ChronobarDev"
    BUNDLE_ID="io.github.nhall.chronobar.dev"
    # Read by BuildVariant in ChronobarCore (dataFolderKey, badgeKey).
    VARIANT_KEYS="    <key>ChronobarDataFolder</key>
    <string>Chronobar Dev</string>
    <key>ChronobarBadge</key>
    <string>DEV</string>
"
else
    NAME="Chronobar"
    EXECUTABLE="Chronobar"
    BUNDLE_ID="io.github.nhall.chronobar"
    VARIANT_KEYS=""
fi

cat <<EOF
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
