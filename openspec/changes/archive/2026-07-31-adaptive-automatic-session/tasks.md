## 1. Public models and configuration

- [x] 1.1 Add `ArgosAutomaticSessionStrategy` and immutable `ArgosAutomaticSessionPolicy` with process/adaptive factories, nullable boundary durations, defaults, and positive-duration assertions.
- [x] 1.2 Add immutable `ArgosSessionContext` with an opaque non-empty fingerprint and defensive-copy string attributes.
- [x] 1.3 Extend `ArgosSessionEndReason` with `backgroundTimeout`, `maxDuration`, and `contextChanged` while preserving tolerant unknown-value JSON parsing.
- [x] 1.4 Add `automaticSessionPolicy` to `ArgosConfig` with the backward-compatible process default and export all new public types from the package barrel.
- [x] 1.5 Add model/config tests for defaults, adaptive overrides, invalid durations, immutable attributes, new endReason round trips, and unknown endReason fallback.

## 2. Automatic-managed session controller

- [x] 2.1 Track whether the active session is automatic-managed and snapshot its policy without reclassifying it during repeated `init()` calls.
- [x] 2.2 Split public explicit session creation from the internal automatic-session creation path so explicit `startSession()` remains policy-independent.
- [x] 2.3 Add internal clock and lifecycle seams for deterministic tests while keeping production behavior on `DateTime.now()`.
- [x] 2.4 Track the current automatic context, max-duration deadline, explicit pause start, and any pending background boundary; reset all controller fields on stop, clear, and testing reset.
- [x] 2.5 Extend pause/resume bookkeeping so explicit paused time shifts the adaptive deadline and resume initially preserves the same sessionId.

## 3. Atomic rollover and dispatch policy

- [x] 3.1 Implement a synchronous internal rollover primitive that completes the old session, activates a new automatic-managed session, resets sequence, and preserves required attributes and policy state.
- [x] 3.2 Queue rollover persistence in strict complete-old → begin-new order without calling public stop or forcing an extra flush.
- [x] 3.3 Sample and isolate the optional context provider, retaining the last valid context when the provider throws.
- [x] 3.4 Evaluate context changes before event metadata allocation, rollover with `contextChanged`, and attach only context attributes—not the fingerprint—to the new session.
- [x] 3.5 Evaluate maxDuration before event metadata allocation, rollover with `maxDuration`, and assign the triggering event to the new session as sequence 1.
- [x] 3.6 Enforce deterministic contextChanged-before-maxDuration priority so one dispatch can perform at most one rollover.
- [x] 3.7 Confirm process, manual, explicitly created, idle, and paused sessions bypass adaptive dispatch checks and retain existing admission behavior.
- [x] 3.8 Add manager tests proving listener metadata and persisted records share the new sessionId/sequence across rollover and that storage operations remain ordered under rapid dispatch.

## 4. Lifecycle-aware background boundaries

- [x] 4.1 Record the adaptive background start on supported lifecycle transitions and preserve the existing background/detached flush behavior.
- [x] 4.2 On resume, keep the same session for elapsed time below backgroundTimeout and clear stale lifecycle candidates safely.
- [x] 4.3 On resume at or beyond backgroundTimeout, perform one `backgroundTimeout` rollover without relying on a background Timer.
- [x] 4.4 Clamp negative elapsed time and calculate old endedAt as no earlier than startedAt, lastEventAt, or the configured background cutoff.
- [x] 4.5 Ensure manual, process, explicitly created, idle, and explicitly paused sessions never rollover because of lifecycle timing.
- [x] 4.6 Add lifecycle tests for short background, exact threshold, long background, clock rollback, explicit pause, detached/interrupted recovery, and repeated resume notifications.

## 5. Persistence and compatibility verification

- [x] 5.1 Verify existing session JSON and the v1 storage envelope persist the new endReason strings without a schemaVersion change or legacy-key rewrite.
- [x] 5.2 Add storage-order tests for complete/begin/append during background, context, and duration rollover, including simultaneous triggers and write failures.
- [x] 5.3 Verify maxSessions eviction treats adaptively completed sessions as whole sessions and never evicts the newly active rollover session.
- [x] 5.4 Verify duplicate init, explicit stop, clear, and process restart preserve existing idempotency and interrupted-recovery behavior.

## 6. Documentation, example, and final validation

- [x] 6.1 Document process versus adaptive automatic behavior, defaults, new-session triggers, explicit-control precedence, and privacy guidance for context fingerprints in README and README_zh.
- [x] 6.2 Update CHANGELOG with the opt-in API and compatibility guarantees.
- [x] 6.3 Add an example toggle or configuration demonstrating adaptive background/max-duration behavior and a cached user/tenant context provider.
- [x] 6.4 Run formatter and analyzer, resolving all issues without modifying unrelated worktree changes.
- [x] 6.5 Run focused adaptive-session tests and the full Flutter test suite.
- [x] 6.6 Run strict OpenSpec validation and manually verify on a simulator/device that short background retains the ID while long background and context changes produce exactly one new ID.
