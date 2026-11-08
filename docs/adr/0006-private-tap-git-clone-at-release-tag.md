# Releases install from a private tap that clones the source at a release tag, with its commit recorded

The Homebrew formula (source of truth `packaging/homebrew/chronobar.rb`, copied to the
`nhall/homebrew-tap` repository) uses a git `url` with both `tag` and `revision`, not a release
tarball. Both repositories are private, and Homebrew downloads tarballs without credentials, whereas a
git clone authenticates with the installer's own GitHub credentials (for example `gh auth setup-git`).
The `revision` records the exact commit the tag named at release; Homebrew's audit requires it next to
a `tag`. Homebrew installs by checking out the tag and doesn't compare it with `revision`, so the
guarantee that a release never changes comes from never moving a release tag, not from the formula.

The formula builds on the user's Mac with the Command Line Tools and signs ad hoc there, so the app
isn't quarantined and needs no Apple Developer account.

## Consequences

- Each release sets the tag, then the formula's `revision` to the tag's commit, in two commits; see
  [Releasing](../contributing/releasing.md).
- Release tags are never moved or reused; a fix after release gets a new version.
- Only people with access to `nhall/chronobar` can install. Going public needs no formula change.
- The build fetches its Swift packages during install, so it needs network access.
