# ENS integration architecture note

The production-grade integration is push-based, versioned, and non-fatal:
- `AGIJobManagerPrime` exposes a stable read interface (`getJobCore`, `getJobSpecURI`, `getJobCompletionURI`) and an ERC-165 marker for compatibility.
- `ENSJobPages` exposes a versioned hook interface (`IENSJobPagesHooksV1`) so selector compatibility is compile-time checked instead of relying on raw calldata.
- Settlement remains independent from ENS writes because every ENS call is best-effort and emits `EnsHookAttempted` with explicit success/failure telemetry.
- Repair is first-class: owners can replay missed events from either side without mutating core escrow history.
- Preview and issuance are separated. `jobEnsPreview(jobId)` is deterministic naming only; `jobEnsIssued(jobId)`/`jobEnsExists(jobId)` prove existence.
- Root safety is enforced at configuration time by requiring normalized ASCII roots and `namehash(rootName) == jobsRootNode`.
