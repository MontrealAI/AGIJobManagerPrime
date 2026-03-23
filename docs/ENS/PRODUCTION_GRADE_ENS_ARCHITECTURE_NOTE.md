# Production-grade ENS integration note

## Why this design is mainnet-ready

- `AGIJobManagerPrime` remains on the selector-stable numeric hook ABI `handleHook(uint8,uint256)` today; typed hooks remain forward-compatible only and are not required for current production readiness.
- Settlement remains independent from ENS writes: the manager emits `EnsHookCallResult` for every best-effort attempt and never makes escrow finalization depend on ENS side effects.
- `ENSJobPages` distinguishes preview from issuance explicitly via `jobEnsPreview`, `jobEnsIssued`, `jobEnsExists`, and `jobEnsStatus`.
- Canonical future names are `agijob-<jobId>.alpha.jobs.agi.eth`; label snapshotting preserves historical labels once issued or migrated.
- Configuration hardening now rejects root-name / root-node mismatches and exposes readiness through `validateConfiguration()` and `isWrappedRootReady()`.
- Repair is explicit: owner operators use the explicit replay/repair entrypoints (`replayCreateExplicit`, `repairTextsExplicit`, `repairAuthorisationsExplicit`, `migrateLegacyWrappedJobPageExplicit`) plus the log-driven scripts under `scripts/ens/`; there is no manager-side `syncEnsForJob` helper.

## Operational consequence

Fresh deployments can be cut over safely because wiring compatibility, root correctness, and wrapped-root approval state can all be checked before traffic is pointed at the new ENS hook target.
