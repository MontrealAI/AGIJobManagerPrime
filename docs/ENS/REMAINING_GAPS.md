# ENS Remaining Gaps (Post-Audit)

## Still missing / incomplete

1. **Lean-mode metadata hydration remains keeper-assisted**
   - This is intentional under unchanged Prime ABI (`handleHook(uint8,uint256)` + fallback getters).
   - Required operation: keep using `repair-from-logs` / `repair-job-page` flows.

2. **Finalization policy remains explicit/manual**
   - Deliberately avoids automatic manager-side fuse burning to preserve Prime size and safety posture.
   - Required operation: continue explicit lock/fuse runbook calls.

3. **Cutover canary automation can still be tightened**
   - Batch scripts and inspector data are now stronger, but staged canary playbooks should continue to evolve with live ops feedback.

## Explicitly closed in this patch

- Added first-class migration contract `ENSJobPagesMigrationHelper` for wrapped/unwrapped unmanaged-node adoption + idempotent create replay.
- ENS-side bytecode gates now include `ENSJobPagesMigrationHelper` by default.
- ENS deploy script now runs ENS artifact budget preflight (limits + minimum headroom) before broadcast.
