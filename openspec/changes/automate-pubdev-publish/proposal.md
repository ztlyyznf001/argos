## Why

`argos 0.3.0` shipped under Mode B (GitHub tag + Release cut, pub.dev publish deferred), so `0.3.0` is tagged but not yet on pub.dev. More broadly, every Argos release to date has run `flutter pub publish` by hand — the maintainer must be present, on the right commit, with the verification gate run manually, which is error-prone and blocks releases on one person's availability. This change publishes `0.3.0` and replaces the manual publish step with a tag-triggered GitHub Actions pipeline using pub.dev's official OIDC-based automated publishing (no long-lived secrets), so pushing a `vX.Y.Z` tag runs the verification gate and publishes the package automatically.

## What Changes

- Add a GitHub Actions workflow (`.github/workflows/publish.yml`) that triggers on pushes of tags matching `v[0-9]+.[0-9]+.[0-9]+`, runs the release-process pre-publish verification gate (`flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`, `flutter pub publish --dry-run`) and, only if all pass, runs `flutter pub publish --force` authenticated via pub.dev automated-publishing OIDC (short-lived token exchanged from GitHub's `id-token` — no stored `PUB_CREDENTIALS`).
- The workflow SHALL verify the tag matches the `pubspec.yaml` `version:` before publishing, to prevent tag/version drift from publishing the wrong version.
- Add a maintainer-facing setup note documenting the one-time pub.dev configuration (enable "Automated publishing" for the `argos` package, set the GitHub repository `ztlyyznf001/argos` and the tag pattern) — a step only the package owner can perform in the pub.dev UI.
- **Publish `0.3.0` via the new pipeline as its first run**: after the workflow and pub.dev config are in place, trigger publishing for the existing `v0.3.0` tag (re-push the tag or `workflow_dispatch`) so the automation itself publishes `0.3.0`, validating the pipeline end-to-end.
- Update the GitHub Release for `v0.3.0` (currently states pub.dev is deferred) once `0.3.0` is live on pub.dev, adding the pub.dev version link per the release-process Release-body format.

## Capabilities

### New Capabilities
<!-- None — this extends the existing release-process capability rather than introducing a new one. -->

### Modified Capabilities
- `release-process`: Adds an automated-publishing pipeline as a first-class publish path — a new **Mode C** (automated CI publish) alongside the existing manual Mode A / Mode B, plus a new requirement defining the tag-triggered, OIDC-authenticated, verification-gated GitHub Actions workflow and the tag↔version match guard. The existing manual modes remain valid fallbacks.

## Impact

- **New file**: `.github/workflows/publish.yml` (GitHub Actions). No `.github/` directory exists yet.
- **Spec**: `openspec/specs/release-process/spec.md` — MODIFIED "Publish ordering" (add Mode C, update the mode count) and ADDED "Automated publishing pipeline" requirement.
- **Docs**: a short "Releasing / automated publishing" section (README or a `RELEASING.md`) covering the one-time pub.dev automated-publishing setup and how to cut a release (push a `vX.Y.Z` tag).
- **External / one-time maintainer action (cannot be done from the repo)**: enabling automated publishing for `argos` on pub.dev and setting the repo + tag pattern; this must be done in the pub.dev UI by the package owner before the pipeline can publish.
- **Permissions**: the workflow needs `id-token: write` (for OIDC) and read access to contents; no repository secret is added.
- **Reversibility**: publishing to pub.dev is irreversible per version; the tag↔version guard and the verification gate running in CI before the publish step are the safeguards against publishing a wrong or broken version.
