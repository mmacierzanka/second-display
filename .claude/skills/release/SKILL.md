---
name: release
description: Cut a Second Display release - pick the next version, bump it in a PR, then tag, build the DMG and publish the GitHub release with notes. Use when asked to bump the version, prepare or publish a release, or write release notes.
---

# Releasing Second Display

## Versioning
- `CFBundleShortVersionString` in `Config/Info.plist` is the only place the version lives. The Makefile reads it for the DMG name, so nothing else needs editing. `CFBundleVersion` (build number) is the commit count; do not touch it.
- [SemVer](https://semver.org) while below 1.0: any user-visible feature since the last release → bump the minor (`0.2.0` → `0.3.0`); only fixes → bump the patch (`0.3.0` → `0.3.1`).
- Tags are the bare version, without a `v` prefix: `0.1.0`, `0.2.0`, ... Lightweight tags, created by `gh release create`.
- To see what is in the release: `git log --oneline --first-parent <last tag>..origin/main`, plus any open PRs meant to ship with it.

## 1. Bump PR
1. Branch `chore/release-X.Y.Z` from `origin/main`.
2. Change `CFBundleShortVersionString` in `Config/Info.plist`, run `make check`.
3. Commit `chore(release): bump version to X.Y.Z` (with the `Co-Authored-By` line) and open a PR with the same title. In its body: the version, the DMG name (`second-display-X.Y.Z.dmg`), the list of changes since the last tag with PR numbers, and which PRs must be merged before it.

## 2. Publish (after the bump PR and everything it waits for are merged)
1. `git checkout main && git pull --ff-only`, working tree clean.
2. `make clean dmg` – builds the universal app and `build/second-display-X.Y.Z.dmg` (ad-hoc signed, not notarized).
3. Write the notes (format below) to a file outside the repo, then:
   `gh release create X.Y.Z build/second-display-X.Y.Z.dmg --target "$(git rev-parse HEAD)" --title "Second Display X.Y.Z" --notes-file <file>`
   The tag goes on the commit the DMG was built from, so the build number inside matches.
4. Publishing is outward-facing: show the user the notes and get a go-ahead before running `gh release create`.

## Release notes
Sections in this order, each omitted when empty. One bullet per merged PR: the PR title without the Conventional Commits prefix, sentence case, PR number at the end. Release and docs-only PRs are left out.

```markdown
## New features

* Picture in picture: a floating app window or the system PiP window (#7)

## Improvements

* Handle denied camera and microphone permissions (#1)

## Bug fixes

* Grey out and skip suspended cameras (#8)

**Full Changelog**: https://github.com/mmacierzanka/second-display/compare/<previous tag>...X.Y.Z
```

- **New features** – `feat:` PRs: something the app could not do before.
- **Improvements** – better behaviour of something that already worked (UX, performance, build/install changes users notice).
- **Bug fixes** – `fix:` PRs: something that did not work as intended.
- Decide by what the user experiences, not only by the commit prefix.
