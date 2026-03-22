# Production-grade ENS integration note

## Why this design is mainnet-ready

- `AGIJobManagerPrime` now pushes lifecycle payloads into a versioned ENS hook interface instead of depending on selector-fragile pull callbacks.
- Settlement remains independent from ENS writes: the manager emits `EnsHookCallResult` for every best-effort attempt and never makes escrow finalization depend on ENS side effects.
- `ENSJobPages` distinguishes preview from issuance explicitly via `jobEnsPreview`, `jobEnsIssued`, `jobEnsExists`, and `jobEnsStatus`.
- Canonical future names are `agijob-<jobId>.alpha.jobs.agi.eth`; label snapshotting preserves historical labels once issued or migrated.
- Configuration hardening now rejects root-name / root-node mismatches and exposes readiness through `validateConfiguration()` and `isWrappedRootReady()`.
- Repair is explicit: owner operators can replay missed manager-side hooks with `syncEnsForJob`, while ENS operators can inspect per-job issuance state before and after replay.

## Operational consequence

Fresh deployments can be cut over safely because wiring compatibility, root correctness, and wrapped-root approval state can all be checked before traffic is pointed at the new ENS hook target.
