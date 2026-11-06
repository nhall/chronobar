# Source of truth for the formula in the nhall/homebrew-tap repo (Formula/chronobar.rb).
# On each release: tag vX.Y.Z, update `url` and `sha256` here, and copy this file to the tap.
class Chronobar < Formula
  desc "Menu bar project timer"
  homepage "https://github.com/nhall/chronobar"
  url "https://github.com/nhall/chronobar/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/nhall/chronobar.git", branch: "main"

  # Builds with the Swift toolchain from the Command Line Tools; Xcode is not required.
  depends_on macos: :sonoma

  def install
    # SwiftPM's own sandbox can't nest inside Homebrew's, and it fetches
    # KeyboardShortcuts (pinned by Package.resolved) during the build.
    ENV["SWIFT_BUILD_FLAGS"] = "--disable-sandbox"
    ENV["VERSION"] = version.to_s
    system "scripts/bundle-app.sh", "build"
    prefix.install "build/Chronobar.app"
  end

  def caveats
    <<~EOS
      Chronobar.app is in #{opt_prefix}. To open it from Spotlight, Launchpad or Finder:
        ln -sfn #{opt_prefix}/Chronobar.app ~/Applications/Chronobar.app
      The link points at Homebrew's "opt" path, so it keeps working after `brew upgrade`.
    EOS
  end

  test do
    app = prefix/"Chronobar.app"
    assert_predicate app/"Contents/MacOS/Chronobar", :executable?
    system "codesign", "--verify", "--deep", "--strict", app
  end
end
