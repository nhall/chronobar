#!/bin/sh
# Assembles Chronobar.app from a release build and ad-hoc signs it, with the `chronobar` command
# in bin/ next to it.
# Needs only the Command Line Tools; Xcode is not required.
#
#   scripts/bundle-app.sh [--dev] [output-dir]      (default: build)
#
# --dev builds "Chronobar Dev.app" instead: a development copy that runs next to the everyday one
# without sharing anything with it. It has its own bundle ID (io.github.nhall.chronobar.dev), so its
# own settings, Selected Project, heartbeat and login item; its own data folder
# (~/Library/Application Support/Chronobar Dev); its own executable name (ChronobarDev, for
# `killall`); and a DEV mark on its Pill and its Dock icon. scripts/info-plist.sh spells all of these.
#
# VERSION sets the bundle version (default 0.1.0). SWIFT_BUILD_FLAGS is passed to
# `swift build`, e.g. SWIFT_BUILD_FLAGS=--disable-sandbox inside a Homebrew build.
set -eu

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
export VERSION

DEV=0
if [ "${1:-}" = "--dev" ]; then
    DEV=1
    shift
fi
OUT="${1:-build}"

# The Info.plist names the copy; the bundle's name and executable are read back from it.
if [ "$DEV" = 1 ]; then
    INFO="$(scripts/info-plist.sh --dev)"
else
    INFO="$(scripts/info-plist.sh)"
fi
info_value() {
    printf '%s\n' "$INFO" | plutil -extract "$1" raw -o - -
}
NAME="$(info_value CFBundleName)"
EXECUTABLE="$(info_value CFBundleExecutable)"
APP="$OUT/$NAME.app"

# shellcheck disable=SC2086
swift build -c release --product Chronobar ${SWIFT_BUILD_FLAGS:-}
# shellcheck disable=SC2086
swift build -c release --product chronobar-cli ${SWIFT_BUILD_FLAGS:-}
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

printf '%s\n' "$INFO" > "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"

# The `chronobar` command, beside the app rather than in it: the same build serves both copies
# (`chronobar --dev` talks to the development one). SwiftPM names it chronobar-cli, as a file system
# that ignores case can't hold `chronobar` next to the app's `Chronobar`.
mkdir -p "$OUT/bin"
cp "$BIN/chronobar-cli" "$OUT/bin/chronobar"
codesign --force --sign - "$OUT/bin/chronobar"
echo "$APP"
