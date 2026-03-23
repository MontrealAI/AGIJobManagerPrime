# Prime ENS Gap Analysis

## Executive conclusion

`AGIJobManagerPrime` does **not** need a runtime patch for production-safe ENS authority semantics. The smallest truthful mainnet architecture is a **keeper-assisted authoritative path** where Prime remains bytecode-frozen and ENS authority snapshotting, inspection, repair, and finalization stay on the ENS side.

## Live chain reconciliation

The 2026-03-23 mainnet audit proves that the currently wired ENSJobPages deployment at `0x97E03F7BFAC116E558A25C8f09aEf09108a2779d` is still a pre-authoritative version: `validateConfiguration()`, `configurationStatus()`, and `jobAuthorityInfo(uint256)` revert on chain. That is a deployment/cutover issue, not a reason to mutate Prime.

## Proven gaps

1. Prime's ENS integration is intentionally best-effort.
2. Prime preserves the wire-compatible hook ABI `handleHook(uint8,uint256)`.
3. Settlement is designed to continue even when ENS side effects fail.
4. Historical ENS identity safety depends on the ENS-side contract using immutable per-job authority snapshots rather than mutable global root/prefix state.
5. Operational correctness still requires inventory, audit, migration, and repair tooling because the live chain may contain mixed historical namespaces and partially hydrated pages.

## Notable non-gaps

- Prime already emits the keeper-grade event data needed for deterministic replay:
  - `JobCreated(..., string jobSpecURI, ...)`
  - `JobCompletionRequested(..., string jobCompletionURI)`
- Prime already exposes the read surface needed by the modern ENS layer:
  - `getJobCore(uint256)`
  - `getJobSpecURI(uint256)`
  - `getJobCompletionURI(uint256)`
- Prime already stores `ensJobPages` as an optional hook target and does not block settlement on hook failure.

## Required semantic split

The ENS layer must expose and document distinct surfaces for:

1. **Preview / projected** values derived from current mutable root + prefix.
2. **Effective / authoritative** values derived from immutable per-job authority snapshots.
3. **Status / repairability** so UIs and operators can detect incomplete or unsafe state without string parsing.
4. **Finalization** as an explicit operator action, not as an implicit settlement side effect.

## Production posture

### Accepted path
- Prime unchanged.
- ENS authority snapshotting in a replacement `ENSJobPages`.
- Inspector + inventory tooling for auditability.
- Owner/keeper replay + repair flows for deterministic hydration.
- Docs and runbooks that explicitly say **preview is not authoritative**.

### Rejected path
- Adding more Prime ENS plumbing before exhausting ENS-side repair and event-sourced replay. The bytecode budget is too tight, and the required semantics are already achievable off the Prime hot path.

## Remaining work after this patch

Only chain-connected execution remains: run the audit/inventory scripts from a networked operator workstation, save the JSON artifacts, then perform migration/repair/finalization according to the runbook.
