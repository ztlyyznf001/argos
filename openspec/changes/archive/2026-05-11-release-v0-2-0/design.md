## Context

Argos is a Flutter plugin published (or to be published) on pub.dev with two platform backends (iOS / Android) and Dart-side `HttpOverrides`. Current state:

- `pubspec.yaml` declares `version: 0.1.0`; `CHANGELOG.md` only documents `0.1.0`.
- Two commits sit on `main` since the `0.1.0` cut: `d204882 Initial release` and `57ab8e7 Add native capture example demo`.
- The repo has no `.github/workflows/`, no release script, and no documented release procedure.
- pub.dev publishing is interactive: `flutter pub publish` requires a logged-in account and prompts for confirmation; it cannot be fully automated without OIDC, which is out of scope for this first cut.

Stakeholders: package maintainer (the user) who will run the publish step; downstream Flutter app authors consuming Argos who get the new example assets and Android Gradle fixes.

## Goals / Non-Goals

**Goals:**
- Ship `0.2.0` to pub.dev with a corresponding git tag `v0.2.0` and GitHub Release.
- Capture a repeatable release checklist as a `release-process` spec so future bumps don't require re-deriving the procedure.
- Catch publish-blockers (analyzer warnings, missing `LICENSE`/`README` metadata, oversized package) before the live publish via `flutter pub publish --dry-run`.

**Non-Goals:**
- Automated release via CI/CD. We intentionally keep the first run manual; OIDC + GitHub Actions publishing can be a follow-up change once the manual flow is proven.
- Renaming, restructuring, or making any API changes — this is a release-only bump.
- Pre-1.0 stability guarantees. We remain in the `0.x` regime where minor bumps can include breaking changes if needed; the spec encodes that policy.

## Decisions

### Decision 1: Version number is `0.2.0`, not `0.1.1` or `1.0.0`

The change between `0.1.0` and now is mostly additive on the Dart surface (new native demo capability, MMKV adapter example) but includes a **breaking Android plugin toolchain bump** (Kotlin 2.0+, AGP 8.7+, JDK 17, `compileSdk 36`, `namespace` declaration) that downstream Android hosts must adopt. Under semver-for-0.x conventions:
- `0.1.1` (patch) is wrong: the spec forbids breaking changes on a patch bump.
- `1.0.0` would imply API stability we are not yet ready to commit to (the public Dart surface is still evolving across recent changes like `pluggable-storage-adapter`, `dynamic-proxy-provider`, etc.).
- `0.2.0` (minor) is correct per the `release-process` spec's pre-1.0 rule: minor MAY carry breaking changes provided `CHANGELOG.md` includes a `### Breaking` subsection (it does).

**Alternatives considered:** `0.1.1` — rejected (semver/spec violation); `1.0.0` — rejected as premature stability commitment.

### Decision 2: Manual publish, codified checklist

Use a documented manual checklist for `0.2.0`, not GitHub Actions automation.

**Why:** Setting up pub.dev OIDC + automated publish requires repo admin configuration on pub.dev and tightens the blast radius of a misconfigured workflow on a first release. A manual cut for `0.2.0`, with the steps written down as a spec, is lower risk and informs what a future automation change would actually need to encode.

**Alternatives considered:** GitHub Actions with `dart-lang/setup-dart` + `flutter pub publish --force` — rejected for this cut; tracked as future work in the `release-process` spec's Open Questions (in this design doc).

### Decision 3: CHANGELOG follows "Keep a Changelog"–lite format already established

`CHANGELOG.md` for `0.1.0` already uses `## <version>` + `### Features` sections. We keep that exact shape for `0.2.0` (with `### Added` / `### Fixed` subsections as needed) rather than migrating to a new format mid-stream.

### Decision 4: Tag format is `v<semver>`

Tag the release commit `v0.2.0` (lowercase `v` prefix). Matches the GitHub default and is the form `gh release create v0.2.0` expects. Encode this in the spec so future cuts are consistent.

### Decision 5: GitHub Release body links the CHANGELOG section

Don't duplicate release notes across CHANGELOG and the GitHub Release body. The Release body should be a short pointer ("See CHANGELOG.md#020 for full notes") plus a link to the pub.dev version. CHANGELOG remains the single source of truth.

## Risks / Trade-offs

- **Risk:** `flutter pub publish` flags a previously-unseen issue (missing platform metadata, `pubspec.yaml` field, oversized assets in `example/`) at the live publish step after the tag is already pushed. → **Mitigation:** Run `--dry-run` *before* tagging; only tag once dry-run is clean. If a fix is needed after tag push, delete the tag (`git push --delete origin v0.2.0`) before publishing the GitHub Release, fix, retag.
- **Risk:** A future contributor cuts `0.2.1` without following the recorded process. → **Mitigation:** The `release-process` spec lives in `openspec/specs/` after archive and is referenced from `CONTRIBUTING.md` (out of scope here, but listed as an Open Question).
- **Trade-off:** Manual publish means the maintainer must be online with pub.dev credentials at release time. Acceptable for current single-maintainer scale; revisit if more maintainers join.
- **Risk:** `example/` directory size could push the published package over pub.dev limits. → **Mitigation:** Dry-run reports package size; if over budget, add an `.pubignore` to exclude `example/build/`, lockfiles, etc. (current `pubspec.lock` is committed but doesn't ship — `flutter pub publish` ignores it by default).

## Migration Plan

No code consumers are affected (additive release). For the release operation itself:

1. Pre-flight on a clean working tree (no uncommitted changes other than the version bump + CHANGELOG).
2. Bump version → update CHANGELOG → commit → push → open PR if branched, or commit directly to `main` per maintainer preference.
3. `flutter pub publish --dry-run` and resolve all warnings.
4. `flutter pub publish` (interactive confirm).
5. `git tag v0.2.0 && git push origin v0.2.0`.
6. `gh release create v0.2.0 --notes "..."` referencing the CHANGELOG section.

**Rollback:** pub.dev does not allow unpublishing a version (only retraction, which still keeps the version listed). Rollback = publish a `0.2.1` with the fix and mark `0.2.0` as retracted via the pub.dev UI if it is genuinely broken. The dry-run + manual confirm steps exist specifically to make this rollback unnecessary.

## Open Questions

- Should `CONTRIBUTING.md` be created/updated in this change to reference the new `release-process` spec? Current `README.md` doesn't mention release procedure. *Proposed answer:* out of scope for this change; add as a follow-up note in the spec's "future work" section so the next contribution picks it up.
- Should we set up pub.dev OIDC + GitHub Actions publishing as a follow-up change after `0.2.0` is out? *Proposed answer:* yes, but as a separate `automate-pub-publishing` proposal, not blocking `0.2.0`.
- Does `example/` need `.pubignore` adjustments? *Resolve during dry-run* — only act if pub.dev reports oversized package or unwanted files in the tarball preview.
