# ENS security note

## Invariants
- Core escrow, dispute, refund, and completion settlement must not depend on ENS success.
- Fresh issuance defaults to `agijob-<jobId>.alpha.jobs.agi.eth`.
- Snapshotted historical labels remain immutable once recorded.
- `jobEnsPreview(jobId)` is never treated as proof of issuance.
- Counterpart contracts must explicitly advertise the expected ERC-165 interfaces before wiring.

## Assumptions
- The configured ENS registry, resolver, and NameWrapper are the canonical mainnet components or compatible replacements.
- Wrapped roots require either direct ownership by `ENSJobPages` or operator approval from the wrapped-root owner.
- Resolver writes can still fail for reasons outside protocol control; operators monitor `EnsHookAttempted` and `ENSHookBestEffortFailure`.

## Residual risks
- Wrapped-root creation is not fully atomic because NameWrapper subname creation and resolver writes are separate operations.
- Off-chain URI content remains mutable unless pinned/content-addressed by operators.
- Replay operations are privileged and therefore depend on disciplined owner/keeper operations.
