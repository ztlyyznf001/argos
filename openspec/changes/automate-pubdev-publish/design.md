## Context

Argos publishes to pub.dev by hand today. The `release-process` spec codifies a manual pre-publish gate (analyze / format / test / dry-run) and two publish orderings: Mode A (publish then tag) and Mode B (tag now, publish deferred). `0.3.0` was cut under Mode B, so `v0.3.0` is tagged and its GitHub Release is live, but the package is not on pub.dev.

pub.dev supports **automated publishing** from GitHub Actions without long-lived credentials: the package owner enables it in the pub.dev admin UI (specifying the GitHub repository and an allowed tag pattern), and a workflow granted `id-token: write` exchanges a GitHub OIDC token for a short-lived pub.dev publishing token via the official `dart-lang/setup-dart` publish flow. This is the mechanism chosen here.

Constraints:
- No `.github/` directory exists yet — this is the repo's first workflow.
- Enabling automated publishing on pub.dev is a one-time UI action only the package owner can perform; the repo change cannot do it. The pipeline will fail to authenticate until it is done.
- `v0.3.0` is already pushed; a tag-triggered workflow added now will not retroactively fire for it. Publishing `0.3.0` therefore requires deliberately (re-)triggering the pipeline against that tag.
- pub.dev publishes are irreversible per version and reject re-publishing an existing version — the pipeline must be safe to re-run.

## Goals / Non-Goals

**Goals:**
- A tag-triggered GitHub Actions pipeline that runs the full verification gate and publishes to pub.dev via OIDC when a `vX.Y.Z` tag is pushed.
- A guard that the pushed tag equals `pubspec.yaml` `version:` before publishing, preventing tag/version drift.
- Publish `0.3.0` as the pipeline's first real run, validating the automation end-to-end.
- Fold automated publishing into the `release-process` spec as Mode C, leaving Mode A / Mode B as valid manual fallbacks.

**Non-Goals:**
- No change to the semver policy, CHANGELOG conventions, or the verification-gate steps themselves — the pipeline runs the *existing* gate, it does not redefine it.
- No automation of the version bump / CHANGELOG authoring / commit / GitHub Release creation — those remain the maintainer's pre-tag responsibility (the pipeline starts at "a version tag was pushed").
- No token-based publishing path (`PUB_CREDENTIALS` secret) — explicitly rejected in favour of OIDC.
- No general CI (test-on-PR) in this change; the workflow is scoped to publish-on-tag. A separate PR-CI workflow can be a later change.

## Decisions

**Decision: OIDC automated publishing via `dart-lang/setup-dart`, not a stored token.**
Chosen by the maintainer. The workflow declares `permissions: id-token: write` and uses the official Dart publishing action, which handles the OIDC token exchange. No secret is stored in the repo, so there is no long-lived credential to leak or rotate. Trade-off: requires the one-time pub.dev-side "Automated publishing" configuration (repo + tag pattern) before it works; until then the publish step fails at auth. Alternative rejected: `PUB_CREDENTIALS` GitHub secret — simpler but stores a long-lived refresh token, which pub.dev discourages.

**Decision: Trigger on `push` of tags matching `v[0-9]+.[0-9]+.[0-9]+`.**
Anchoring on the annotated version tag keeps CI aligned with the existing convention (`version: X.Y.Z` ↔ tag `vX.Y.Z`) and the pub.dev allowed-tag-pattern. `workflow_dispatch` is also enabled so a tag can be (re-)published manually — needed to publish the already-pushed `v0.3.0`, and useful for retrying a transient failure. Alternative rejected: publish on push to `main` — would republish on every merge and fights pub.dev's "version already exists" rejection.

**Decision: Tag↔version match guard runs before publish and hard-fails on mismatch.**
The job checks out the tagged ref, reads `version:` from `pubspec.yaml`, strips the `v` from the tag, and fails the job if they differ. This stops a mistaken tag (e.g. `v0.4.0` on a commit whose pubspec still says `0.3.0`) from publishing the wrong version. It also makes the pipeline honour the spec's "no version skipping or reuse" and Mode B "source unchanged" intent mechanically.

**Decision: Run the full verification gate in CI before the publish step; publish only on green.**
The job runs `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test`, and `flutter pub publish --dry-run` as ordered steps; any failure stops the job before `flutter pub publish`. This moves the spec's manual gate into CI so an automated publish is never less-verified than a manual one. On a checked-out clean tag, the dirty-git-state dry-run warnings seen during the manual `0.3.0` cut do not occur.

**Decision: Publish step tolerates "already published" without failing the pipeline red for re-runs — but never overwrites.**
pub.dev rejects re-publishing an existing version; a re-run of the workflow for an already-published tag should surface clearly, not be treated as a hard infrastructure failure. The publish step uses `flutter pub publish --force` (non-interactive) and the job treats pub.dev's "version already exists" as a no-op success signal in the summary, while a genuine publish error fails the job. (Kept simple: the guard + gate mean the common re-run case is an already-published version.)

**Decision: Publish `0.3.0` via `workflow_dispatch` against `v0.3.0`, then refresh its GitHub Release.**
Rather than delete/re-push the tag (which rewrites release history), dispatch the workflow with the `v0.3.0` ref. After the package is live, update the existing `v0.3.0` Release body to drop the "pub.dev deferred" note and add the pub.dev version link, satisfying the spec's Release-body-format requirement.

## Risks / Trade-offs

- **[pub.dev automated-publishing not yet configured]** → the pipeline's publish step fails at OIDC auth. Mitigation: the setup doc lists the one-time pub.dev UI step as a prerequisite; the maintainer completes it before the first dispatch. The verification gate still runs and passes, so the failure is isolated to the auth/publish step and is retryable via `workflow_dispatch`.
- **[Tag pushed on the wrong commit]** → could publish an unintended version. Mitigation: the tag↔version guard hard-fails on mismatch before publish.
- **[Irreversible publish of a broken version]** → Mitigation: the full gate runs in CI before publish; publishing only proceeds on green. A version can never be un-published, only a new patch cut — unchanged from today.
- **[`0.3.0` source drift vs the tag]** → the Mode B "source drifted → cut a new patch" rule still governs; because the pipeline checks out the tag exactly and the guard enforces pubspec==tag, dispatching `v0.3.0` publishes precisely the tagged content.
- **[Workflow uses a floating action version]** → supply-chain risk. Mitigation: pin `dart-lang/setup-dart` (and any other actions) to a specific released version rather than a moving `@v1`/branch ref.

## Migration Plan

1. Land the workflow + docs + spec delta on `main` (normal PR/commit — this is not itself a package release).
2. Maintainer performs the one-time pub.dev "Automated publishing" setup (repo `ztlyyznf001/argos`, tag pattern `v{{version}}`).
3. `workflow_dispatch` the publish workflow against `v0.3.0`; confirm `argos 0.3.0` appears on pub.dev.
4. Refresh the `v0.3.0` GitHub Release body (remove deferral note, add pub.dev link).
5. From then on, releases follow Mode C: cut the commit + CHANGELOG + tag as today, push the `vX.Y.Z` tag, and the pipeline publishes automatically.

Rollback: the workflow is inert unless a matching tag is pushed or it is dispatched. Removing/disabling the workflow file reverts to manual Mode A / Mode B with no residue. Nothing about adding the workflow is irreversible; only an actual pub.dev publish is.

## Open Questions

- Which exact pinned versions of `dart-lang/setup-dart` (and the Flutter setup action, if used) to adopt — resolve at implementation time against the latest released tags.
- Whether to also add a PR-triggered CI (analyze/test) workflow — out of scope here; can be proposed separately.
