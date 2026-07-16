# release-process Specification

## Purpose
TBD - created by archiving change release-v0-2-0. Update Purpose after archive.
## Requirements
### Requirement: Semver versioning policy

Argos SHALL follow Semantic Versioning 2.0.0 with the following pre-1.0 clarification: while the version starts with `0.`, the minor segment MAY include backwards-incompatible changes, and the patch segment MUST be reserved for bug fixes that preserve the public API surface.

The `version:` field in `pubspec.yaml` SHALL be the single source of truth for the current released version. Git tags SHALL match this value with a `v` prefix (e.g., `version: 0.2.0` ↔ tag `v0.2.0`).

#### Scenario: Minor bump for additive feature

- **WHEN** a release contains new capabilities or new public Dart API entries that do not remove or rename existing ones
- **THEN** the minor segment SHALL be incremented and the patch segment SHALL be reset to `0` (e.g., `0.1.0` → `0.2.0`)

#### Scenario: Patch bump for bug-fix-only release

- **WHEN** a release contains only bug fixes, documentation updates, or non-API-affecting refactors
- **THEN** the patch segment SHALL be incremented (e.g., `0.2.0` → `0.2.1`)

#### Scenario: Breaking change in pre-1.0

- **WHEN** a release removes or renames a public Dart API entry while the version is still `0.x.y`
- **THEN** the minor segment SHALL be incremented and the CHANGELOG entry MUST include a `### Breaking` subsection listing each break with a migration note

### Requirement: CHANGELOG conventions

Every release SHALL prepend a new `## <version>` section to `CHANGELOG.md` at the top of the file, above prior entries. The section MUST be written and committed before `flutter pub publish` is invoked, because pub.dev surfaces the latest CHANGELOG section on the package page.

Subsections inside a release entry MUST use `### <category>` headings drawn from this set: `Added`, `Changed`, `Fixed`, `Removed`, `Breaking`, `Features` (legacy, used by `0.1.0`). New entries SHOULD prefer `Added` / `Changed` / `Fixed` over the legacy `Features` heading.

#### Scenario: Release section is present before publish

- **WHEN** a release is being cut for version `X.Y.Z`
- **THEN** `CHANGELOG.md` MUST contain a `## X.Y.Z` section as its first version heading before `flutter pub publish` is run

#### Scenario: Empty CHANGELOG section blocks release

- **WHEN** the `## X.Y.Z` section exists but contains no bullet points under any subsection
- **THEN** the release MUST NOT be published until the section lists at least one user-visible change

### Requirement: Pre-publish verification

Before invoking `flutter pub publish`, the maintainer MUST run, in order, and resolve each step before proceeding:

1. `flutter analyze` — MUST exit with no errors. Warnings SHOULD be addressed; if intentionally deferred, they MUST be noted in the release commit message.
2. `dart format --set-exit-if-changed .` (or `flutter format`) — MUST exit clean.
3. `flutter test` — MUST exit with all tests passing.
4. `flutter pub publish --dry-run` — MUST report `Package has 0 warnings.` (or only warnings the maintainer has explicitly accepted in writing in the release commit message).

#### Scenario: Dry-run reports warnings

- **WHEN** `flutter pub publish --dry-run` reports one or more warnings
- **THEN** the maintainer MUST either fix the underlying issue and re-run the dry-run, OR document the accepted warning in the release commit message before proceeding to the live publish

#### Scenario: Analyzer error in pre-flight

- **WHEN** `flutter analyze` reports any error
- **THEN** the release MUST NOT proceed; the error MUST be fixed in a commit on the release branch

### Requirement: Publish ordering

The release MAY proceed in one of two modes. In both modes, steps SHALL execute in order with each step completing successfully before the next.

**Mode A — Full publish (pub.dev + GitHub):**

1. Commit the version bump and CHANGELOG update onto the release branch.
2. Merge to `main` (or commit directly to `main` if maintainer policy allows).
3. Run pre-publish verification.
4. `flutter pub publish` and confirm interactively.
5. `git tag v<version>` on the merged commit and `git push origin v<version>`.
6. `gh release create v<version>` referencing the CHANGELOG section.

In Mode A the tag MUST NOT be pushed before `flutter pub publish` succeeds, because pub.dev is the irreversible step and tagging a commit whose publish failed creates downstream confusion about which version is live.

**Mode B — GitHub-only first, pub.dev deferred:**

1. Commit + merge as in Mode A steps 1–2.
2. Run pre-publish verification.
3. `git tag v<version>` and `git push origin v<version>`.
4. `gh release create v<version>` referencing the CHANGELOG section, and the Release body MUST explicitly state that pub.dev publishing is deferred so downstream consumers are not surprised.
5. *(Deferred)* When the maintainer later runs `flutter pub publish` for the same `<version>`:
   - The pubspec `version:` on the tagged commit MUST still equal `<version>`.
   - Pre-publish verification MUST be re-run on the tagged commit.
   - If any source change has happened between the tag and the deferred publish, the maintainer MUST cut a new patch version instead of publishing the original tag's content.

Mode B is appropriate when the maintainer wants the release artifact (tag + GitHub Release) cut immediately but is deferring pub.dev publish (e.g., waiting on credentials, validating with downstream consumers first, or deliberately not publishing to pub.dev for that version).

#### Scenario: Mode A — publish fails, tag not yet pushed

- **WHEN** `flutter pub publish` reports an error in Mode A and the maintainer has not yet pushed the tag
- **THEN** the maintainer SHALL fix the underlying issue, create a new commit, and restart the publish sequence from step 3 without rolling back any branch state

#### Scenario: Mode A — publish succeeds, tag and Release follow

- **WHEN** `flutter pub publish` reports `Package <name> <version> uploaded`
- **THEN** the maintainer SHALL within the same working session push the matching `v<version>` git tag and create the GitHub Release

#### Scenario: Mode B — deferred publish, source unchanged

- **WHEN** the maintainer runs `flutter pub publish` against the Mode B tag commit and `git diff v<version>..HEAD -- pubspec.yaml lib/` reports no changes
- **THEN** publish MAY proceed under the original `v<version>` tag without re-tagging

#### Scenario: Mode B — deferred publish, source has drifted

- **WHEN** the maintainer is ready to run `flutter pub publish` and the working tree contains changes to `pubspec.yaml` or `lib/` since `v<version>` was tagged
- **THEN** publish MUST NOT use the existing `v<version>` and MUST instead cut a new patch version (e.g., `v<version+1>`) with its own commit, tag, and CHANGELOG entry

### Requirement: GitHub Release body format

The GitHub Release body SHALL be a short pointer to the canonical CHANGELOG section, not a duplicated copy of release notes. It MUST contain:

1. A link to the `CHANGELOG.md` section anchor on `main` at the release commit (e.g., `https://github.com/ztlyyznf001/argos/blob/v0.2.0/CHANGELOG.md`).
2. A link to the pub.dev page for the released version (e.g., `https://pub.dev/packages/argos/versions/0.2.0`).

The Release title SHALL be exactly `v<version>` (matching the tag).

#### Scenario: Release body is a pointer, not a duplicate

- **WHEN** a GitHub Release is created for version `X.Y.Z`
- **THEN** the Release body MUST link to `CHANGELOG.md` and to the pub.dev version page, and MUST NOT copy the full CHANGELOG content inline

### Requirement: No version skipping or reuse

Once a version has been published to pub.dev, that exact `version:` value MUST NOT be reused for a different commit. The next release MUST increment from the previously published version according to the semver policy above. Versions MAY NOT be skipped (e.g., going from `0.2.0` directly to `0.4.0` without a `0.3.0`) unless a `0.3.0` was published, retracted, and a CHANGELOG note documents the retraction.

#### Scenario: Attempt to republish same version

- **WHEN** `pubspec.yaml` declares `version: X.Y.Z` and `X.Y.Z` already exists on pub.dev
- **THEN** the maintainer MUST bump to the next semver value (patch for fixes, minor for additions) before attempting publish

