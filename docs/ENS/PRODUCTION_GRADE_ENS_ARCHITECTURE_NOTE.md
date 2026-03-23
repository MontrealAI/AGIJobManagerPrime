# Production-grade ENS integration note

## Why this design is mainnet-ready

- `AGIJobManagerPrime` remains on the selector-stable `handleHook(uint8,uint256)` path today; production readiness comes from ENS-side compatibility mode plus explicit repair flows, not from a Prime runtime rewrite.
- Settlement remains independent from ENS writes: the manager emits `EnsHookCallResult` for every best-effort attempt and never makes escrow finalization depend on ENS side effects.
- `ENSJobPages` distinguishes preview from issuance explicitly via `jobEnsPreview`, `jobEnsIssued`, `jobEnsExists`, and `jobEnsStatus`.
- Canonical future names are `agijob-<jobId>.alpha.jobs.agi.eth`; label snapshotting preserves historical labels once issued or migrated.
- Configuration hardening now rejects root-name / root-node mismatches and exposes readiness through `validateConfiguration()` and `isWrappedRootReady()`.
- Repair is explicit: owner operators can replay missed manager-side hooks with the real owner-callable `replay*` / `repair*` functions, while ENS operators can inspect per-job issuance state before and after replay.

## Operational consequence

Fresh deployments can be cut over safely because wiring compatibility, root correctness, and wrapped-root approval state can all be checked before traffic is pointed at the new ENS hook target.
