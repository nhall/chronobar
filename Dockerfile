# `chronobar mcp` on Linux, built as Glama builds it (docs/adr/0009-mcp-server-builds-on-linux-for-glama.md):
# Glama generates its own Dockerfile from the build spec in its admin page, a Debian bookworm image with the
# repository in /app and scripts/linux-build.sh as the build step. This one does the same, so the Test
# workflow checks that build. Chronobar itself is a macOS app: here the server answers initialize and
# tools/list, and every tool call reports that it runs only on macOS.
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
COPY . .
RUN sh scripts/linux-build.sh
CMD ["chronobar", "mcp"]
