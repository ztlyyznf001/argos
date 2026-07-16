## 1. Author the publish workflow

- [x] 1.1 Create `.github/workflows/publish.yml` triggered on `push` of tags matching `v[0-9]+.[0-9]+.[0-9]+` and on `workflow_dispatch` (with an optional tag/ref input for manual runs).
- [x] 1.2 Grant the job `permissions: id-token: write` (and `contents: read`); do not reference any `PUB_CREDENTIALS` secret.
- [x] 1.3 Check out the exact tagged ref and set up Flutter/Dart, pinning `dart-lang/setup-dart` (and the Flutter setup action, if used) to specific released versions — not moving `@v1`/branch refs. → `actions/checkout@v4.2.2`, `subosito/flutter-action@v2.18.0` (Flutter setup provides Dart; confirm these are the latest patch releases before relying on them).
- [x] 1.4 Add a tag↔version guard step: read `version:` from `pubspec.yaml`, compare against the tag with its leading `v` stripped, and fail the job on mismatch before any publish step.
- [x] 1.5 Add the verification-gate steps in order — `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test`, `flutter pub publish --dry-run` — so any failure stops the job before publish.
- [x] 1.6 Add the publish step: `flutter pub publish --force` authenticated via the OIDC flow, running only after the guard and gate pass.

## 2. Document the release process

- [x] 2.1 Add a "Releasing / automated publishing" section (README or a new `RELEASING.md`) covering: the one-time pub.dev "Automated publishing" setup (enable for `argos`, set repo `ztlyyznf001/argos` and tag pattern), and the normal release flow (cut commit + CHANGELOG, push `vX.Y.Z` tag → pipeline publishes). → new `RELEASING.md`.
- [x] 2.2 Cross-link the doc to the `release-process` spec's Mode C so the manual Mode A/B fallbacks stay discoverable. → RELEASING.md references the spec and documents Mode A/B/C.

## 3. Land the change

- [ ] 3.1 Commit the workflow + docs (this is a tooling change, not itself a package release — no version bump).
- [ ] 3.2 Push to `main`.

## 4. One-time pub.dev configuration (maintainer, in pub.dev UI)

- [ ] 4.1 On pub.dev, enable "Automated publishing" for the `argos` package, set the GitHub repository to `ztlyyznf001/argos`, and set the allowed tag pattern to `v{{version}}` (matching the workflow trigger). — cannot be done from the repo; the package owner must do this before the pipeline can authenticate.

## 5. Publish 0.3.0 via the pipeline (first real run)

- [ ] 5.1 Confirm `v0.3.0`'s commit still has `pubspec.yaml` `version: 0.3.0` (tag↔version guard will enforce this).
- [ ] 5.2 Trigger the workflow against `v0.3.0` via `workflow_dispatch` (do not delete/re-push the tag — that would rewrite release history).
- [ ] 5.3 Confirm the run passes the guard + verification gate and that `argos 0.3.0` appears on pub.dev.

## 6. Finalize the 0.3.0 release artifact

- [ ] 6.1 Update the existing `v0.3.0` GitHub Release body: remove the "pub.dev publishing is deferred" note and add the pub.dev version link (`https://pub.dev/packages/argos/versions/0.3.0`), per the release-process Release-body-format requirement.
- [ ] 6.2 Verify the Release body remains a pointer (CHANGELOG link + pub.dev link), not a duplicated copy of the notes.
