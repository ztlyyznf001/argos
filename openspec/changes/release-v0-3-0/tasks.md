## 1. Prepare release branch

- [x] 1.1 Create a `release-v0.3.0` branch off `main` (feature code for the bundled batch is currently uncommitted in the working tree; it will be committed as part of this release).
- [x] 1.2 Confirm the bundled batch is present in the working tree: `ArgosCapability.{crash,jank,resource}` in `lib/config/argos_config.dart`, new `lib/apm/argos_{crash,jank,resource}_monitor.dart`, new `lib/model/argos_{crash,jank,resource}_info_model.dart`, `lib/ui/argos_ui_kit.dart`, and the new exports in `lib/argos.dart`.

## 2. Version bump and CHANGELOG

- [x] 2.1 Bump `pubspec.yaml` `version:` from `0.2.0` to `0.3.0`.
- [x] 2.2 Prepend a `## 0.3.0` section to `CHANGELOG.md` above the `## 0.2.0` entry, using `### Added` / `### Changed` / `### Fixed` subsections.
- [x] 2.3 Under `### Added`, list the APM monitors batch (`add-apm-monitors`): new `ArgosCapability.crash` / `.jank` / `.resource`; crash/error capture, jank analysis, resource (memory) monitors; new exported models and monitors; new `ArgosConfig` fields `resourceMaxRecords`, `jankThresholdMultiplier`, `resourceSampleInterval`, `storagePersistInterval`; new `argos_ui_kit` export.
- [x] 2.4 Under `### Changed`, list the Inspector UI batch (`improve-record-display-ui`): event-type filter (all / network / crash / jank / resource), resource-sample aggregation, kind-dispatched detail page (network keeps request/response tabs; crash/jank/resource get purpose-built views), denser network rows, dark-mode-aware theming; and the storage batches: `clear()`/`getAllAsync()` now serialize through the write chain with coalesced writes (`harden-storage-concurrency`), and retention is now per-`kind` FIFO with a separate `resourceMaxRecords` cap so routine resource samples never evict a captured crash or request (`per-kind-storage-quota`).
- [x] 2.5 Verify each of the four bundled archived changes is attributed by at least one bullet (rollup-release requirement), and confirm no `### Breaking` subsection is needed (batch is additive for a 0.2.0 consumer).
- [x] 2.6 Confirm the `## 0.3.0` section is non-empty and is the first version heading in `CHANGELOG.md`.

## 3. Pre-publish verification (release-process gate)

- [x] 3.1 Run `flutter analyze` — MUST exit with no errors; fix any error as a commit on the release branch (note deliberately-deferred warnings in the release commit message). → No issues found.
- [x] 3.2 Run `dart format --set-exit-if-changed .` — MUST exit clean; commit any formatting changes. → Reformatted 6 files; re-run reports 0 changed.
- [x] 3.3 Run `flutter test` — MUST pass. (If iOS/device builds are needed they will fail codesign under the iCloud-synced repo path; the gate here is analyze/format/test only, which is unaffected.) → 41/41 passed.
- [x] 3.4 Run `flutter pub publish --dry-run` — MUST report `Package has 0 warnings.`; fix or document each warning in the release commit message before proceeding. → 2 warnings, both dirty-git-state only (uncommitted modified files + deleted v0-2-0 files); no package-content warnings. Resolve on commit; Mode B re-runs the clean dry-run at deferred-publish time.

## 4. Commit and merge

- [ ] 4.1 Commit the version bump, CHANGELOG, and the bundled feature batch on the `release-v0.3.0` branch with a clear release commit message noting any accepted warnings.
- [ ] 4.2 Merge `release-v0.3.0` to `main` (or fast-forward per maintainer policy).

## 5. Mode B — tag and GitHub Release (pub.dev deferred)

- [ ] 5.1 `git tag v0.3.0` on the merged `main` commit and `git push origin v0.3.0`.
- [ ] 5.2 `gh release create v0.3.0` with title exactly `v0.3.0`; the body is a short pointer to the `CHANGELOG.md` section at the tagged commit (e.g. `https://github.com/ztlyyznf001/argos/blob/v0.3.0/CHANGELOG.md`) and MUST explicitly state that pub.dev publishing is deferred.
- [ ] 5.3 Confirm the Release body is a pointer, not a duplicated copy of the release notes.

## 6. Record deferred-publish follow-up

- [ ] 6.1 Note (in the change or an issue) that `flutter pub publish` for `0.3.0` is deferred, and that per the release-process Mode B rules the deferred publish MUST re-run verification on the tagged commit and MUST cut a new patch version if `pubspec.yaml`/`lib/` has drifted since `v0.3.0` was tagged.
