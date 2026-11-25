# `chronobar mcp` on Linux, for Glama, which builds this image, starts the server and lists its tools
# to score them (docs/adr/0009-mcp-server-builds-on-linux-for-glama.md). Chronobar itself is a macOS
# app: here the server answers initialize and tools/list, and every tool call reports that the app
# isn't running. To use Chronobar, install it with Homebrew on a Mac (docs/install.md).
FROM swift:6.2-noble AS build
WORKDIR /src
COPY . .
RUN swift build -c release --product chronobar-cli

FROM swift:6.2-noble-slim
COPY --from=build /src/.build/release/chronobar-cli /usr/local/bin/chronobar
ENTRYPOINT ["chronobar"]
CMD ["mcp"]
