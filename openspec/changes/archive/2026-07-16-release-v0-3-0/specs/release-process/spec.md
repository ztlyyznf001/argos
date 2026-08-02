## ADDED Requirements

### Requirement: Rollup releases bundle multiple archived changes

A single release MAY bundle more than one already-archived change into one published version. When a release bundles N archived changes, the version bump SHALL be computed from the union of all bundled changes' public-API and behavioural effects: the release is a minor bump if any bundled change adds public API, and MUST include a `### Breaking` subsection if any bundled change removes or renames a public API entry.

The `## <version>` CHANGELOG section for a rollup release SHALL attribute each bundled change so per-change traceability is preserved — every bundled change MUST be represented by at least one bullet whose content is traceable to that change (for example by grouping bullets under the originating change or naming it inline).

A rollup release SHALL NOT introduce new feature code of its own beyond the version bump and CHANGELOG update; the bundled changes MUST already be implemented before the release is cut.

#### Scenario: Version bump reflects the union of bundled changes

- **WHEN** a release bundles multiple archived changes and at least one of them adds public API while none removes or renames existing public API
- **THEN** the release SHALL be a minor bump and the CHANGELOG section MUST NOT be forced to include a `### Breaking` subsection

#### Scenario: Any bundled breaking change forces a Breaking subsection

- **WHEN** a rollup release bundles a change that removes or renames a public API entry
- **THEN** the `## <version>` CHANGELOG section MUST include a `### Breaking` subsection listing each break with a migration note

#### Scenario: Each bundled change is attributed in the CHANGELOG

- **WHEN** a rollup release bundles N archived changes
- **THEN** the `## <version>` CHANGELOG section MUST contain at least one bullet traceable to each of the N bundled changes

#### Scenario: Rollup release adds no new feature code

- **WHEN** a rollup release is being cut
- **THEN** the release commit MUST NOT introduce feature code beyond what the bundled changes already implemented, aside from the `pubspec.yaml` version bump and the `CHANGELOG.md` section
