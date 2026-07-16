## Context

`0.2.0` is the currently-published version and `v0.2.0` sits at `HEAD`. Since then, four changes have been fully specced and archived under `openspec/changes/archive/` but their code lives **only in the working tree** (uncommitted modified + untracked files):

- `2026-07-13-add-apm-monitors` — crash/error capture, jank analysis, resource (memory) monitor; new `ArgosCapability.{crash,jank,resource}`, `lib/apm/*`, `lib/model/argos_{crash,jank,resource}_info_model.dart`, new exports.
- `2026-07-14-improve-record-display-ui` — event-type filter, resource aggregation, kind-dispatched detail page, denser rows, dark-mode theming, `lib/ui/argos_ui_kit.dart`.
- `2026-07-15-harden-storage-concurrency` — `clear()`/`getAllAsync()` serialized through the write chain; coalesced writes via `storagePersistInterval`.
- `2026-07-15-per-kind-storage-quota` — per-`kind` FIFO retention with a dedicated `resourceMaxRecords` cap.

This change is a **rollup release**: it does not write feature code. It bundles the already-implemented batch into a single published version by bumping the version, writing the CHANGELOG, running the `release-process` verification gate, and cutting the tag + GitHub Release. The maintainer chose **Mode B** (GitHub-first, pub.dev deferred).

Constraints:
- The `release-process` spec (`openspec/specs/release-process/spec.md`) is the governing checklist and must be followed verbatim.
- Per the iCloud/codesign memory note, this repo lives under an iCloud-synced `~/Documents`, which breaks iOS build codesign — irrelevant here since the release gate runs `flutter analyze` / `dart format` / `flutter test`, not device builds.

## Goals / Non-Goals

**Goals:**
- Cut `0.3.0` bundling the four archived changes into one coherent, documented version.
- Produce a `## 0.3.0` CHANGELOG section that attributes each bundled change and lists the additive public API + the one behavioural change.
- Execute the Mode B publish ordering: commit → merge to `main` → verify → tag `v0.3.0` → GitHub Release (body states pub.dev deferred).
- Codify the rollup-release pattern in `release-process` so future batched releases are consistent.

**Non-Goals:**
- No feature code changes — the APM/UI/storage code is already implemented; this release only publishes it.
- No `flutter pub publish` in this change — pub.dev is deferred (Mode B). The deferred publish is a later, separate action governed by the existing Mode B requirements.
- No new APM capability specs — those already live under `openspec/specs/` from their own changes.

## Decisions

**Decision: Version is `0.3.0` (minor bump), not `0.2.1` or `1.0.0`.**
The batch adds new public API (three `ArgosCapability` values, four `ArgosConfig` fields, new exported models/monitors/UI kit) without removing or renaming existing entries. Under the `release-process` semver policy, additive public API → minor bump. Alternatives rejected: `0.2.1` (patch is reserved for API-preserving bug fixes — this adds API); `1.0.0` (no intent to declare a stable 1.0 surface yet).

**Decision: The kind-dispatched detail page is documented as Changed, not Breaking, in the CHANGELOG.**
`improve-record-display-ui` marked the detail-page dispatch **BREAKING** relative to its own post-`add-apm-monitors` baseline. But a `0.2.0` consumer only ever had `network` records, whose request/response detail view is unchanged. Crash/jank/resource records did not exist in `0.2.0`, so their new detail views are additive from the `0.2.0` → `0.3.0` vantage point. No `### Breaking` subsection is required; the dispatch is noted under `### Changed`.

**Decision: Mode B (GitHub-first, pub.dev deferred).**
Chosen by the maintainer. The tag + GitHub Release are cut immediately; `flutter pub publish` is deferred. The Release body MUST state the deferral so downstream consumers are not surprised, per the `release-process` Mode B requirement. When the deferred publish later happens, the existing Mode B "source unchanged / source drifted" scenarios govern whether `v0.3.0` can be published as-is or a new patch must be cut.

**Decision: Commit the uncommitted working-tree batch as part of the release, on a release branch off `main`.**
Because the feature code is uncommitted, the release commit necessarily carries both the feature batch and the version/CHANGELOG bump. Work happens on a `release-v0.3.0` branch, then merges to `main`, keeping `main` clean if verification fails. Alternative rejected: committing directly on `main` — riskier if the verification gate surfaces failures mid-release.

**Decision: Codify "rollup release" in the `release-process` spec.**
This is the first release that bundles multiple already-archived changes. Adding a requirement that (a) permits one version to bundle N archived changes and (b) mandates the CHANGELOG attribute each bundled change makes the pattern reusable and keeps the spec the source of truth. This is the only spec delta in this change.

## Risks / Trade-offs

- **[Verification gate fails on the bundled feature code]** → The release commit carries a large batch that has not been run through `flutter analyze` / `dart format` / `flutter test` as a unit. Mitigation: run the full gate on the release branch before merging; fix failures as commits on the branch (allowed by the Mode A/B "restart from verification" scenarios). Do not tag until the gate is green.
- **[Deferred pub.dev creates a version-drift window]** → Between tagging `v0.3.0` and the eventual `flutter pub publish`, `pubspec.yaml`/`lib/` could change. Mitigation: the existing Mode B requirements already mandate cutting a new patch if source drifts before the deferred publish; the Release body flags the deferral so consumers know pub.dev lags GitHub.
- **[CHANGELOG under-attributes the batch]** → Bundling four changes into one section risks losing per-change traceability. Mitigation: the new rollup requirement mandates attributing each bundled change; the `## 0.3.0` section groups bullets by originating change.

## Migration Plan

For **downstream consumers** upgrading `0.2.0` → `0.3.0`: additive only. New capabilities are opt-in via `ArgosCapability`; new `ArgosConfig` fields have backward-compatible defaults (`resourceMaxRecords: 50`, `jankThresholdMultiplier: 1.0`, `resourceSampleInterval: 2s`, `storagePersistInterval: 5s`). Existing `maxPacketRecords` keeps its meaning for non-resource kinds. No code changes required to stay on current behaviour, except that enabling `resource`/`crash`/`jank` capabilities activates the new monitors.

Rollback: Mode B is reversible up to the deferred publish. If a defect is found after tagging but before pub.dev publish, delete/replace the tag and Release and cut a corrected patch — nothing irreversible has happened yet.

## Open Questions

- None blocking. The pub.dev deferral end-date is out of scope for this change and will be handled by the existing Mode B deferred-publish flow when the maintainer is ready.
