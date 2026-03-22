# ENS integration security note

## Invariants

- Core escrow, dispute, and settlement flows must succeed even if every ENS call fails.
- A preview name is not proof of issuance; only `jobEnsIssued/jobEnsExists` should be treated as issuance truth.
- Future default naming is `agijob-<jobId>` and already snapshotted labels are immutable.
- `jobsRootName` must be normalized lowercase ASCII and must namehash to `jobsRootNode`.

## Assumptions

- The configured ENS root is owned either directly by `ENSJobPages` or by the NameWrapper with active approval for `ENSJobPages`.
- The configured resolver supports the text/auth flows used by the contract.
- Operators monitor `EnsHookCallResult` and replay missed updates with `syncEnsForJob` when needed.

## Residual risks

- Resolver writes can still fail or be censored; this is observable but intentionally non-fatal.
- NameWrapper permissions can be revoked after deployment; readiness must be rechecked before operational changes.
- Historical labels migrated from legacy deployments depend on accurate operator-provided snapshots.
