## 1. Prepare release branch

- [ ] 1.1 Create a release branch from the current `main` HEAD: `git switch -c release/v0.2.0`
- [ ] 1.2 Confirm working tree is clean: `git status` reports nothing to commit other than the upcoming edits

## 2. Bump version and CHANGELOG

- [x] 2.1 Edit `pubspec.yaml`: change `version: 0.1.0` to `version: 0.2.0`
- [x] 2.2 Edit `CHANGELOG.md`: prepend a `## 0.2.0` section above the existing `## 0.1.0` section
- [x] 2.3 Under `## 0.2.0`, add `### Added` bullets for: native capture example demo (iOS/Android `NativeDemoChannel` + `native_demo_page.dart`), MMKV storage adapter example (`example/lib/mmkv_storage_adapter.dart`), `native-capture-example` capability spec
- [x] 2.4 Under `## 0.2.0`, add `### Changed` bullets for: Android Gradle/manifest updates (build.gradle, AndroidManifest.xml additions, settings.gradle), iOS Podfile updates, fps/http model adjustments
- [x] 2.5 Under `## 0.2.0`, add `### Fixed` bullets for any bug fixes surfaced by `git diff d204882..HEAD`; if none, omit the subsection — folded into Changed; Android plugin toolchain bumps surfaced as a new `### Breaking` subsection
- [x] 2.6 Verify the CHANGELOG entry is non-empty and human-readable as it will appear on pub.dev

## 3. Pre-publish verification

- [x] 3.1 Run `flutter analyze` — fix any error before continuing — clean, no issues
- [x] 3.2 Run `dart format --set-exit-if-changed .` — apply formatting and amend the version-bump commit if changes are produced — 4 files reformatted (`example/test/widget_test.dart`, `lib/storage/argos_packet_storage.dart`, `lib/ui/argos_packet_detail_page.dart`, `lib/ui/argos_packet_list_page.dart`)
- [x] 3.3 Run `flutter test` — all tests must pass — 6/6 pass
- [x] 3.4 Run `flutter pub publish --dry-run` from the repo root — initial run flagged missing Dart SDK upper bound; fixed `pubspec.yaml` env to `sdk: '>=2.17.0 <4.0.0'`
- [x] 3.5 If dry-run reports warnings: triage each. Fix in code where possible; if accepted, record the warning text in the release commit message body — only remaining warning is "checked-in files are modified in git", expected pre-commit; will be 0 warnings after release commit lands
- [x] 3.6 If dry-run reports oversized package or unwanted files (e.g., `example/build/`, IDE files), add or update `.pubignore` to exclude them, then re-run dry-run — archive is 328 KB; no `.pubignore` change needed

## 4. Commit and merge

- [ ] 4.1 Stage `pubspec.yaml`, `CHANGELOG.md`, and any formatting/`.pubignore` changes from section 3
- [ ] 4.2 Commit with message `Release v0.2.0` and a body summarising the CHANGELOG bullets
- [ ] 4.3 Push the release branch and open a PR against `main` (or skip PR and push directly to `main` if maintainer policy allows)
- [ ] 4.4 Merge to `main` once green; ensure the merge commit is the one that will be tagged

## 5. Publish to pub.dev

- [ ] 5.1 On `main` at the merge commit, re-run `flutter pub publish --dry-run` to confirm the final state still passes
- [ ] 5.2 Run `flutter pub publish` and confirm interactively at the pub.dev prompt
- [ ] 5.3 Verify the new version is live: open `https://pub.dev/packages/argos/versions/0.2.0` and confirm metadata, README rendering, and CHANGELOG section show correctly

## 6. Tag and GitHub Release

- [ ] 6.1 Create the tag on the merge commit: `git tag v0.2.0`
- [ ] 6.2 Push the tag: `git push origin v0.2.0`
- [ ] 6.3 Create the GitHub Release: `gh release create v0.2.0 --title "v0.2.0" --notes "See CHANGELOG.md for full notes. https://pub.dev/packages/argos/versions/0.2.0"`
- [ ] 6.4 Open the created Release on GitHub and confirm the body renders correctly with both links live

## 7. Archive release-process spec

- [ ] 7.1 After publish + tag + Release are live, run `openspec archive release-v0-2-0` (or the `/opsx:archive` skill) to fold the `release-process` capability into `openspec/specs/`
- [ ] 7.2 Confirm `openspec/specs/release-process/spec.md` now exists in the main specs directory and the change folder is moved to `openspec/changes/archive/`

## 8. Follow-ups (out of scope for this change, log only)

- [ ] 8.1 Open a tracking note (issue or `openspec` proposal) for automating pub.dev publishing via GitHub Actions + OIDC as a future change
- [ ] 8.2 Open a tracking note for adding a `CONTRIBUTING.md` that references the new `release-process` spec
