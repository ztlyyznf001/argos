# Releasing Argos

The canonical rules live in the `release-process` capability spec
(`openspec/specs/release-process/spec.md`). This doc is the practical checklist.

Argos follows Semantic Versioning (pre-1.0: the minor segment may carry
breaking changes; the patch segment is reserved for API-preserving fixes).
`pubspec.yaml` `version:` is the single source of truth; the git tag is that
value with a `v` prefix (`version: 0.3.0` ↔ tag `v0.3.0`).

## Automated publishing (Mode C — default)

Pushing a version tag publishes to pub.dev automatically via
`.github/workflows/publish.yml`. The workflow runs the full pre-publish
verification gate (`flutter analyze`, `dart format --set-exit-if-changed .`,
`flutter test`, `flutter pub publish --dry-run`) and only publishes if the gate
passes **and** the tag matches `pubspec.yaml` `version:`. Authentication uses
pub.dev's OIDC-based automated publishing — no long-lived credential is stored
in the repository.

### One-time setup (maintainer, pub.dev UI)

Before the pipeline can publish, the package owner must enable automated
publishing on pub.dev:

1. Go to <https://pub.dev/packages/argos/admin> (package admin).
2. Under **Automated publishing**, enable **publishing from GitHub Actions**.
3. Set **Repository** to `ztlyyznf001/argos`.
4. Set the **Tag pattern** to `v{{version}}` (matches the workflow's
   `v[0-9]+.[0-9]+.[0-9]+` trigger).

Until this is configured, the workflow's **Publish to pub.dev** step fails at
authentication; every other step still runs.

### Cutting a release

1. Bump `pubspec.yaml` `version:` and prepend a `## <version>` section to
   `CHANGELOG.md` (see the spec's CHANGELOG conventions).
2. Commit and merge to `main`.
3. Tag and push: `git tag v<version> && git push origin v<version>`.
4. The pipeline runs on the tag push. Confirm the run is green and
   `<version>` is live at `https://pub.dev/packages/argos/versions/<version>`.
5. Create the GitHub Release: `gh release create v<version>` with a body that
   points to the `CHANGELOG.md` section and the pub.dev version page (a pointer,
   not a copy of the notes).

### Publishing an already-pushed tag / retrying

Use **workflow_dispatch** with the tag as the `ref` input (Actions →
*Publish to pub.dev* → *Run workflow*). This avoids deleting/re-pushing the tag
and rewriting release history. pub.dev rejects re-publishing a version that
already exists.

## Manual fallbacks (Mode A / Mode B)

The manual publish orderings remain valid when CI is unavailable:

- **Mode A — Full publish:** run the verification gate locally, then
  `flutter pub publish`, then tag + GitHub Release. Do not push the tag before
  the publish succeeds.
- **Mode B — GitHub-first, pub.dev deferred:** commit + merge, tag + Release
  now (Release body states pub.dev is deferred), and publish later. If
  `pubspec.yaml`/`lib/` has drifted since the tag, cut a new patch version
  instead of publishing the old tag's content.

See `openspec/specs/release-process/spec.md` for the full requirements and
scenarios governing all three modes.
