# The public tap keeps cloning the source at the release tag

Supersedes [ADR 0006](0006-private-tap-git-clone-at-release-tag.md).

`nhall/chronobar` and `nhall/homebrew-tap` are public, so anyone can run
`brew install nhall/tap/chronobar` without GitHub credentials. ADR 0006 chose a git `url` with `tag`
and `revision` because the repositories were private and Homebrew downloads tarballs without
credentials. That reason is gone, but the formula keeps the git `url`: it is a supported form for a
tap, the release steps stay the same, and switching to a tarball `url` would add a `sha256` to compute
on every release for no gain to users.

The rest of ADR 0006 still holds: the `revision` records the commit the tag named at release, and the
formula builds and signs ad hoc on the user's Mac with the Command Line Tools.

## Consequences

- Installing needs no GitHub account or `gh auth setup-git`.
- Each release still sets the tag, then the formula's `revision` to the tag's commit; see
  [Releasing](../contributing/releasing.md).
- Release tags are never moved or reused; a fix after release gets a new version.
- The build fetches its Swift packages during install, so it needs network access.
- Issues, pull requests, release notes and the full history of both repositories are public.
