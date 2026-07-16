## MODIFIED Requirements

### Requirement: Publish ordering

The release MAY proceed in one of the following modes. In every mode, steps SHALL execute in order with each step completing successfully before the next.

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

**Mode C — Automated publish via CI:**

1. Commit the version bump and CHANGELOG update and merge to `main`.
2. `gh release create v<version>` referencing the CHANGELOG section (MAY be created before or after publish, since in Mode C the tag push — not a manual `flutter pub publish` — is the trigger).
3. `git tag v<version>` on the merged commit and `git push origin v<version>`.
4. The automated publishing pipeline (see the **Automated publishing pipeline** requirement) runs on the tag push: it re-runs pre-publish verification on the tagged commit and, only if the gate passes and the tag matches the pubspec version, publishes `<version>` to pub.dev via OIDC.

In Mode C the tag push IS the publish trigger, so pushing `v<version>` before the pipeline is configured, or before the pubspec version matches the tag, will not silently publish the wrong artifact — the pipeline's tag↔version guard and verification gate stop it. The maintainer MUST confirm the pipeline run succeeded and `<version>` is live on pub.dev before considering the release complete.

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

#### Scenario: Mode C — tag push triggers an automated publish

- **WHEN** the maintainer pushes a `v<version>` tag whose commit's `pubspec.yaml` declares `version: <version>` and the automated publishing pipeline is configured
- **THEN** the pipeline SHALL run the pre-publish verification gate and, only on success, publish `<version>` to pub.dev without any manual `flutter pub publish` invocation

#### Scenario: Mode C — pipeline not yet configured

- **WHEN** a `v<version>` tag is pushed but pub.dev automated publishing has not been enabled for the package
- **THEN** the pipeline's publish step SHALL fail at authentication and MUST NOT publish, and the release is not complete until the maintainer configures automated publishing and re-triggers the pipeline

## ADDED Requirements

### Requirement: Automated publishing pipeline

The repository SHALL provide a GitHub Actions workflow that publishes the package to pub.dev automatically when a version tag is pushed, using pub.dev's OIDC-based automated publishing rather than a stored credential.

The workflow SHALL:

- Trigger on pushes of tags matching the version-tag pattern `v[0-9]+.[0-9]+.[0-9]+`, and additionally support manual `workflow_dispatch` against an existing tag.
- Declare `id-token: write` permission so a short-lived pub.dev publishing token can be exchanged from GitHub's OIDC provider; it MUST NOT rely on a long-lived `PUB_CREDENTIALS` repository secret.
- Check out the exact tagged commit and, before publishing, assert that `pubspec.yaml` `version:` equals the tag with its leading `v` removed; on mismatch the job MUST fail without publishing.
- Run the pre-publish verification gate (`flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test`, `flutter pub publish --dry-run`) and MUST NOT reach the publish step if any gate step fails.
- Pin third-party actions (e.g. the Dart/Flutter setup and publish actions) to specific released versions rather than moving refs.

Enabling automated publishing for the package on pub.dev (repository and allowed tag pattern) is a one-time maintainer action performed in the pub.dev UI and is a prerequisite for the workflow's publish step to authenticate; this SHALL be documented for the maintainer.

#### Scenario: Tag matches pubspec version — publish proceeds

- **WHEN** the workflow runs for a pushed tag `v<version>` and the checked-out `pubspec.yaml` declares `version: <version>` and the verification gate passes
- **THEN** the workflow SHALL publish `<version>` to pub.dev via the OIDC-exchanged token

#### Scenario: Tag does not match pubspec version — publish blocked

- **WHEN** the workflow runs for a pushed tag `v<version>` but the checked-out `pubspec.yaml` declares a different version
- **THEN** the job MUST fail at the tag↔version guard and MUST NOT invoke `flutter pub publish`

#### Scenario: Verification gate fails — publish blocked

- **WHEN** any of `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test`, or `flutter pub publish --dry-run` fails in the workflow
- **THEN** the job MUST stop before the publish step and MUST NOT publish to pub.dev

#### Scenario: No stored publishing credential

- **WHEN** the automated publishing workflow authenticates to pub.dev
- **THEN** it SHALL use an OIDC-exchanged short-lived token and MUST NOT read a long-lived `PUB_CREDENTIALS` secret from the repository
