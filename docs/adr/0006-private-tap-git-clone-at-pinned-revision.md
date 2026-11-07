# Releases install from a private tap that clones the source at a pinned tag and revision

The Homebrew formula (source of truth `packaging/homebrew/chronobar.rb`, copied to the
`nhall/homebrew-tap` repository) uses a git `url` with both `tag` and `revision`, not a release
tarball. Both repositories are private, and Homebrew downloads tarballs without credentials, whereas a
git clone authenticates with the installer's own GitHub credentials (for example `gh auth setup-git`).
The `revision` pins the exact commit the tag named at release, so moving the tag can't silently change
what installs.

The formula builds on the user's Mac with the Command Line Tools and signs ad hoc there, so the app
isn't quarantined and needs no Apple Developer account.

## Consequences

- Each release sets the tag, then the formula's `revision` to the tag's commit, in two commits; see
  [Releasing](../contributing/releasing.md).
- Only people with access to `nhall/chronobar` can install. Going public needs no formula change.
- The build fetches its Swift packages during install, so it needs network access.
