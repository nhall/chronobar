#!/bin/sh
# Builds `chronobar mcp` on Debian 12 (bookworm) and installs it as /usr/local/bin/chronobar, for Glama
# (docs/adr/0009-mcp-server-builds-on-linux-for-glama.md). Run as root from the repository's root.
#
# Glama's build spec runs this as its only build step, and the repository's Dockerfile runs it the same
# way, so the Test workflow's `linux (MCP image)` job checks the build Glama makes.
#
# The Swift runtime is linked into the binary (--static-swift-stdlib), so the toolchain is deleted
# afterwards: it would otherwise add about 1 GB to the image, which Glama is slow to upload.
set -eu

SWIFT_VERSION=6.2.4

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl git binutils libc6-dev libcurl4-openssl-dev libedit2 libgcc-12-dev libpython3-dev \
    libsqlite3-0 libstdc++-12-dev libxml2-dev libncurses-dev libz3-dev pkg-config tzdata zlib1g-dev
rm -rf /var/lib/apt/lists/*

case "$(uname -m)" in
    aarch64) platform=debian12-aarch64 ;;
    *) platform=debian12 ;;
esac
mkdir -p /opt/swift
curl -fsSL "https://download.swift.org/swift-$SWIFT_VERSION-release/$platform/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-$platform.tar.gz" \
    | tar xz --strip-components=1 -C /opt/swift

/opt/swift/usr/bin/swift build -c release --product chronobar-cli --static-swift-stdlib
cp .build/release/chronobar-cli /usr/local/bin/chronobar
rm -rf /opt/swift .build /root/.cache /root/.swiftpm
