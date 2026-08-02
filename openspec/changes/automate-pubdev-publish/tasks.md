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

- [x] 3.1 Commit the workflow + docs (this is a tooling change, not itself a package release — no version bump). → commit `d01a6fe`.
- [x] 3.2 Push to `main`. → pushed `68574c6..d01a6fe`; workflow live on GitHub.

> **Plan correction (discovered during apply):** pub.dev's "Automated publishing" admin page only exists for a package that is *already published*, and `argos` was never published (0.3.0 was Mode B / GitHub-only). So the pipeline cannot bootstrap a brand-new package — the **first** publish must be a manual `flutter pub publish`. Separately, re-running the gate on the `v0.3.0` tag revealed `flutter analyze` exits non-zero there (an `if` that `dart format` wrapped across two lines, tripping `curly_braces_in_flow_control_structures`; analyze during the 0.3.0 release ran *before* format). Fix + patch bump → **0.3.1**, which becomes the first published version. Groups 4–6 are re-scoped below.

## 4. Bootstrap the package via a manual first publish (0.3.1)

- [x] 4.1 Fix the `curly_braces_in_flow_control_structures` lint in `ArgosPacketDetailPage._parseFormBody` (add braces). → analyze clean on `main`.
- [x] 4.2 Bump `pubspec.yaml` to `0.3.1` and prepend a `## 0.3.1` CHANGELOG section (Fixed: the lint; notes 0.3.1 is the first pub.dev-published version). Removed stray iCloud ` 2.dart` conflict copies that were failing analyze.
- [x] 4.3 Run the verification gate on `main`: `flutter analyze` (no issues), `dart format --set-exit-if-changed .` (clean), `flutter test` (41/41). Commit `07201eb`; push `main`; create local tag `v0.3.1` (held, not pushed — Mode A: push tag after publish succeeds).
- [x] 4.4 Verify a clean dry-run at `v0.3.1` in a throwaway worktree: `flutter analyze` clean, `flutter pub publish --dry-run` → 0 warnings (417 KB archive).
- [x] 4.5 **(Maintainer — interactive)** Run `flutter pub publish` to establish the package on pub.dev. → Two blockers surfaced and were resolved: (a) the shell's `PUB_HOSTED_URL` pointed at the `pub.flutter-io.cn` mirror (download-only), fixed by publishing with `PUB_HOSTED_URL=https://pub.dev`; (b) pub.dev rejected the name `argos` as too similar to `argo` — **renamed the package to `argos_inspector`** (commit `41e8f3c`; all imports → `package:argos_inspector/...`; entry `lib/argos_inspector.dart`; docs/workflow updated; API class names unchanged), moved tag `v0.3.1`→`569c6b4`. OAuth completed via the browser. **Published: `argos_inspector 0.3.1` → https://pub.dev/packages/argos_inspector**.
- [x] 4.6 After publish succeeds: push the tag and create the GitHub Release with a pointer body. → pushed `main` (`41e8f3c`) + tag `v0.3.1`; Release at https://github.com/ztlyyznf001/argos/releases/tag/v0.3.1 (links CHANGELOG + pub.dev).

## 5. Enable pub.dev automated publishing (maintainer, pub.dev UI) — now possible

- [ ] 5.1 With the package now existing on pub.dev, go to `https://pub.dev/packages/argos_inspector/admin`, enable "Automated publishing" from GitHub Actions, set repository `ztlyyznf001/argos`, and set the tag pattern to `v{{version}}` (matches the workflow trigger). *(Package published as `argos_inspector` — see the group-4 rename note.)*

## 6. Validate automation on the next release (0.3.2+)

- [ ] 6.1 On the next change, cut a normal release (bump, CHANGELOG, commit, push `vX.Y.Z` tag). The pipeline should run the guard + gate and auto-publish to pub.dev with no manual `flutter pub publish` — confirm the run is green and the version is live.
- [ ] 6.2 (Optional) Note in `RELEASING.md` that 0.3.1 was the manual bootstrap and automation is live from the next tag onward.
