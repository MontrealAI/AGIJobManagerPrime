# Observed Mainnet State

_As of 2026-03-23 UTC this sandbox could not reach Ethereum mainnet RPC (latest `scripts/ens/audit-mainnet.ts` run returned `AggregateError`). This file therefore distinguishes proven local facts from chain facts that must be re-read using the included audit scripts from a networked operator workstation._

## Proven locally

- The preferred production architecture is Prime unchanged, ENS-side authority snapshotting, and keeper/operator replay/repair tooling.
- The active ENS contract surface exposes a preview/effective split: `previewJobEns*`, `effectiveJobEns*`, compatibility getters (`jobEnsName`, `jobEnsURI`, `jobEnsNode`), `jobAuthorityInfo`, `jobEnsStatus`, and `configurationStatus`.
- `ENSJobPages` stores immutable per-job authority data once established: label hash, root version, authoritative root node, authoritative node, source, version, timestamp, legacy-import flag, and finalization flags.
- Prime keeps the hook ABI `handleHook(uint8,uint256)` and already emits `JobCreated` plus `JobCompletionRequested`, enabling a manager-unchanged keeper path.

## Requires explicit chain read (`scripts/ens/audit-mainnet.ts`)

### ENSJobPages live state
- owner
- ens
- nameWrapper
- publicResolver
- jobsRootNode
- jobsRootName
- jobManager
- jobLabelPrefix
- configLocked
- useEnsJobTokenURI

### Prime live state
- owner
- discoveryModule
- ensJobPages
- whether Prime currently points to the intended ENSJobPages deployment

### Wrapped-root readiness
- whether `jobsRootNode` is wrapped
- wrapped owner
- `getApproved`
- `isApprovedForAll`
- whether ENSJobPages is presently authorized to operate the wrapped root

### Root integrity
- ENSIP-15 normalized root name
- computed namehash
- equality between computed namehash and `jobsRootNode`

### Resolver compatibility
- `supportsInterface(0x59d1d43c)` text
- `supportsInterface(0x10f13a8c)` setText
- `supportsInterface(0x304e6ade)` setAuthorisation

### Historical inventory
- preview-only jobs
- label-snapshotted-only jobs
- authority-snapshotted jobs
- legacy import candidates
- unmanaged nodes
- resolver mismatch jobs
- metadata-incomplete jobs
- repairable jobs
- authoritative-ready jobs
- finalized jobs

## Proven vs assumed

### Proven in this repository
- Preview values are projections, not authoritative identity.
- Effective values are read from immutable per-job authority snapshots.
- Root mutation no longer changes historical effective identity once authority is established.
- Settlement is architected to stay non-blocking even if ENS calls fail.

### Assumed until chain replay succeeds
- The exact live owner/resolver/approval values at the supplied mainnet addresses.
- Whether `configLocked` has been called on the live deployment.
- The current historical inventory across all live jobs/pages.

## Required operator action

Run both scripts below from a networked environment and commit the generated JSON artifacts before mainnet cutover decisions. The checked-in `scripts/ens/output/audit-mainnet.json` from this sandbox run is explicitly non-authoritative because RPC was unreachable:

- `node scripts/ens/audit-mainnet.ts`
- `node scripts/ens/inventory-job-pages.ts`
