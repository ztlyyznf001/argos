## Why

Since `0.2.0` we have landed a large batch of APM work that expands Argos from "network + basic FPS" into a four-signal APM tool — crash/error capture, jank analysis, and resource (memory) sampling — plus an event-type-aware Inspector UI and two storage-layer correctness/retention fixes. All of it currently lives only in the working tree and the OpenSpec archive; consumers on `0.2.0` cannot get any of it from pub.dev. This change cuts `0.3.0` following the existing `release-process` spec so the batch ships as one coherent, documented version.

## What Changes

- Bump `pubspec.yaml` `version:` from `0.2.0` to `0.3.0` (minor bump — additive public API, no removals).
- Prepend a `## 0.3.0` section to `CHANGELOG.md` summarising everything landed since `0.2.0`:
  - **APM monitors** (`add-apm-monitors`): new `ArgosCapability.crash`, `.jank`, `.resource`; new monitors under `lib/apm/` and models under `lib/model/`; new public exports in `lib/argos.dart`.
  - **Inspector UI** (`improve-record-display-ui`): event-type filter (all / network / crash / jank / resource), resource-sample aggregation, kind-dispatched detail page, denser network rows, dark-mode-aware theming.
  - **Storage concurrency** (`harden-storage-concurrency`): `clear()` and `getAllAsync()` now serialize through the write chain; write coalescing removes per-write full re-encode.
  - **Per-kind storage quota** (`per-kind-storage-quota`): retention is now per-`kind` FIFO with a separate `resourceMaxRecords` cap so routine resource samples can never evict a captured crash or request.
- Run the `release-process` pre-publish verification (analyze, format, tests, `pub publish --dry-run`) and resolve any warnings.
- Publish `argos 0.3.0` per the `release-process` publish-ordering requirement, then tag `v0.3.0` and create the matching GitHub Release pointing at the new CHANGELOG section.

## Capabilities

### New Capabilities
<!-- None — the APM capabilities (crash-error-capture, jank-analysis, resource-monitor) were already specced by their own changes and now live under openspec/specs/. This release introduces no new capability. -->

### Modified Capabilities
<!-- None — no requirement-level changes. The release-process spec already governs this release unchanged, and all behavioural specs already reflect the 0.3.0 code that this release merely publishes. -->

## Impact

- **Files**: `pubspec.yaml` (version), `CHANGELOG.md` (new `## 0.3.0` section). No `openspec/specs/` changes.
- **Public Dart API (additive, non-breaking for 0.2.0 consumers)**: new `ArgosCapability` values `crash` / `jank` / `resource`; new `ArgosConfig` fields `resourceMaxRecords`, `jankThresholdMultiplier`, `resourceSampleInterval`, `storagePersistInterval`; new exported types (crash/jank/resource models + monitors, `argos_ui_kit`). Existing API is unchanged; `maxPacketRecords` keeps its meaning for non-resource kinds but is now a per-kind cap rather than a global total.
- **Behavioural change (not an API break)**: the Inspector detail page now dispatches by record kind; crash/jank/resource records show purpose-built views instead of the network request/response tabs. Network records — the only kind a 0.2.0 consumer had — are unaffected.
- **Tooling / external**: requires a configured pub.dev publisher and `flutter pub publish` access; produces a published `argos 0.3.0` on pub.dev and a `v0.3.0` tag + GitHub Release on `ztlyyznf001/argos`.
