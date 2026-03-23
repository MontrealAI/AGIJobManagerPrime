# ENS Job Pages Behavior Overview

This document describes the current Prime-compatible ENS job-page model implemented in `contracts/ens/ENSJobPages.sol` and `contracts/ens/ENSJobPagesInspector.sol`.

## Canonical semantics

- **Preview / projected** values come from the currently configured prefix + root and are exposed by:
  - `previewJobEnsLabel(jobId)`
  - `previewJobEnsName(jobId)`
  - `previewJobEnsURI(jobId)`
  - `previewJobEnsNode(jobId)`
- **Effective / authoritative** values exist only after authority is snapshotted and are exposed by:
  - `effectiveJobEnsLabel(jobId)`
  - `effectiveJobEnsName(jobId)`
  - `effectiveJobEnsURI(jobId)`
  - `effectiveJobEnsNode(jobId)`
- **Compatibility getters** (`jobEnsLabel`, `jobEnsName`, `jobEnsURI`, `jobEnsNode`) return effective values once authority exists; otherwise they fall back to preview values. They are compatibility surfaces only and must not be treated as authoritative before authority is established.

## Canonical default shape

- `jobLabelPrefix = agijob-`
- `jobsRootName = alpha.jobs.agi.eth`
- Preview names therefore look like `agijob-<jobId>.alpha.jobs.agi.eth`.

## Authority and root-versioning

`ENSJobPages` snapshots both:

1. the exact job label; and
2. the exact root version used when authority is established.

That means root or prefix changes do **not** retroactively rename historical jobs once authority exists.

### Repair safety rule

`repairAuthoritySnapshot(jobId, exactLabel)` is intentionally limited to single-root deployments. In multi-root deployments operators must use `repairAuthoritySnapshotExplicit(jobId, exactLabel, rootVersionId)` so a historical job cannot be silently bound to the wrong root version.

## Prime compatibility model

`AGIJobManagerPrime` remains ABI-compatible through `handleHook(uint8,uint256)`.

`ENSJobPages.handleHook(...)` now performs runtime capability detection:

- **Rich manager path:** if the manager exposes `IAGIJobManagerPrimeViewV1`, ENS reads full job views directly.
- **Prime fallback path:** if the manager does not expose V1 views, ENS still auto-issues identity on create using `jobEmployerOf(jobId)` and still repairs/revokes/locks authorisations using the available public employer/agent getters. Missing URIs are treated as explicit repair requirements, never as success.

Settlement remains non-blocking in both paths.

## Repair and replay model

The contract now exposes explicit owner repair entrypoints that do **not** rely on unavailable Prime V1 getters:

- `repairAuthoritySnapshotExplicit(jobId, exactLabel, rootVersionId)`
- `repairResolver(jobId)`
- `repairSpecTextExplicit(jobId, specURI)`
- `repairCompletionTextExplicit(jobId, completionURI)`
- `repairTextsExplicit(jobId, specURI, completionURI)`
- `repairAuthorisationsExplicit(jobId, employer, agent, allowAuth)`
- `replayCreateExplicit(jobId, employer, specURI)`
- `replayAssignExplicit(jobId, agent)`
- `replayCompletionExplicit(jobId, completionURI)`
- `replayRevokeExplicit(jobId, employer, agent)`
- `replayLockExplicit(jobId, employer, agent, burnFuses)`

The older convenience functions remain useful only when the manager exposes the richer V1 view surface.

## Compatibility truth model

- `jobEnsIssued(jobId)` now means: authoritative node exists onchain.
- `jobEnsReady(jobId)` now means: authoritative node exists, expected resolver is set, and base metadata (`schema` + spec text) is present.

These compatibility booleans do **not** claim completion metadata, auth state, or finalization truth.

## Resolver and auth observations

The inspector does not assume every resolver exposes `isAuthorised(bytes32,address)`. Instead it reports whether auth observation is supported and keeps “unknown” separate from “false”.

## Wrapped-name operations

- Wrapped roots require either direct wrapper ownership, token approval, or operator approval.
- Wrapped child creation/adoption stays best-effort and non-blocking for settlement.
- Fuse burning remains explicit/manual-or-helper driven unless an operator intentionally calls lock/burn repair paths.

## Operator scripts

Use the ENS scripts under `scripts/ens/` before cutover:

- `audit-mainnet.ts`
- `phase0-mainnet-snapshot.mjs`
- `inventory-job-pages.ts`
- `repair-from-logs.ts`
- `repair-job-page.ts`
- `migrate-legacy-batch.ts`

Each script emits machine-readable JSON under `scripts/ens/output/` for auditability.
