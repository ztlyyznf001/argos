## Why

Since the initial `0.1.0` release we have shipped a native capture example (`native-capture-example` spec + iOS/Android demo channels, MMKV storage adapter sample, native demo page) plus several Android/Gradle and packaging fixes. Users on `0.1.0` cannot pick those improvements up from pub.dev, and we have no documented procedure for cutting Argos releases, so each future bump risks ad-hoc inconsistency.

This change cuts `0.2.0` and, while we are doing it, codifies the Argos release procedure as a first-class spec so subsequent versions follow the same checklist.

## What Changes

- Bump `pubspec.yaml` `version:` from `0.1.0` to `0.2.0`.
- Prepend a `## 0.2.0` section to `CHANGELOG.md` summarising additions since `0.1.0` (native capture example demo, MMKV adapter sample, Android Gradle/manifest tweaks, fps/http model adjustments, test updates).
- Run pub publish dry-run, fix any analyzer/format warnings it surfaces, and publish to pub.dev.
- Tag the release commit `v0.2.0` and publish a matching GitHub Release pointing at the new CHANGELOG section.
- Document the above as a reusable `release-process` capability so the next bump (0.2.x / 0.3.0) is mechanical.

## Capabilities

### New Capabilities
- `release-process`: Defines the Argos versioning policy, CHANGELOG conventions, pre-publish verification (analyze, format, tests, pub dry-run), pub.dev publish step, and git tag + GitHub Release procedure.

### Modified Capabilities
<!-- None — no behavioural spec changes; the existing capability specs (http-capture-pipeline, native-capture-example, etc.) remain accurate for 0.2.0. -->

## Impact

- **Files**: `pubspec.yaml` (version), `CHANGELOG.md` (new section), new `openspec/specs/release-process/spec.md` after archive.
- **Tooling**: requires a configured pub.dev publisher account and `flutter pub publish` access for whoever cuts the release.
- **External**: a new published version on pub.dev (`argos 0.2.0`) and a `v0.2.0` tag + Release on GitHub `ztlyyznf001/argos`.
- **No public Dart API additions or removals** — the Dart surface is unchanged.
- **Breaking for downstream Android hosts**: the Android plugin's `build.gradle` requires Kotlin 2.0+, AGP 8.7+, JDK 17 and `compileSdk 36`; hosts still on AGP 7 / JDK 11 will fail to configure. This is permitted under the `release-process` spec's pre-1.0 minor-bump-with-breaking rule and is recorded under `### Breaking` in `CHANGELOG.md`.
