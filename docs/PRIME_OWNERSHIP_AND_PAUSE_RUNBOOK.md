# Prime Ownership + Pause Runbook (Mainnet)

## Ownership model (business-operated, strong control)

`AGIJobDiscoveryPrime` uses two-step ownership handoff:
1. Current owner calls `transferOwnership(newOwner)` to set `pendingOwner`.
2. `pendingOwner` calls `acceptOwnership()` to finalize.

`AGIJobManagerPrime` keeps one-step ownership transfer for bytecode-budget safety (mainnet deployability), with `renounceOwnership` disabled.

Safety guarantees:
- `renounceOwnership()` is disabled.
- zero-address ownership transfers are rejected (both contracts).
- discovery owner can call `cancelOwnershipTransfer()` to clear a mistaken pending owner.
- discovery owner can supersede a pending handoff by calling `transferOwnership(...)` again.

EOA vs multisig:
- both are supported (any non-zero address can be pending owner).
- for production, use a business-controlled multisig as the long-term owner.

## Pause architecture

Prime now uses a pause architecture:
- **Manager intake pause** (`pause()` / `unpause()`): blocks new manager exposure entrypoints while leaving already-live manager progression paths open (because progression paths are not gated by `whenNotPaused`).
- **Discovery intake pause** (`setIntakePaused(bool)`): blocks new discovery market entry while keeping ongoing workflows open where safe.
- **Settlement freeze** (manager `setSettlementPaused(bool)`): blocks adjudication/finalization/value-moving settlement paths in manager and downstream discovery winner/cancel/fallback operations.
- **Full emergency pause** (`pause()` / `unpause()` on discovery, and manager `pause()` + `setSettlementPaused(true)` together when broad freeze is required).

Manager exposes `settlementPaused` and `paused` (paused doubles as intake stop for manager entrypoints). Discovery exposes `intakePaused` and `paused` (its settlement gating follows manager settlement freeze where applicable).

## Pause matrix

### AGIJobManagerPrime

| Function group | Intake pause | Settlement freeze | Full emergency |
|---|---:|---:|---:|
| create/configure job (`createJob`, `createConfiguredJob`, `createConfiguredJobFor`) | blocked | blocked | blocked |
| assignment intake (`applyForJob`, `designateSelectedAgent`, `setPerJobAgentRoot`) | blocked | blocked | blocked |
| checkpoint submit / completion request / validator votes / dispute open | allowed | allowed | blocked |
| dispute resolution / stale dispute resolution / finalization / expiry / employer cancel | allowed | blocked | blocked |
| treasury withdrawal (`withdrawAGI`) | unchanged (owner-only + emergency paused required) | blocked | allowed if settlement freeze is off |
| ENS/job-page hooks | best-effort side effects; failures remain non-fatal in every mode |

### AGIJobDiscoveryPrime

| Function group | Intake pause | Settlement freeze (manager) | Full emergency |
|---|---:|---:|---:|
| create premium procurement / attach procurement / commit application | blocked | allowed | blocked |
| reveal application / shortlist finalization / finalist accept / trial / score commit+reveal | allowed | allowed | blocked |
| winner finalization / fallback promotion / procurement cancel-unwind | allowed | blocked | blocked |
| claims (`claim`) | allowed | allowed | allowed |
| autonomous advancement (`advanceProcurement`) | stage-dependent; respects both local + settlement pause states |

## Incident runbook

### Intake incident (spam/new-risk containment)
1. set intake pause on manager and/or discovery.
2. keep settlement unfrozen so live users can complete already-started flows.
3. monitor pause booleans + automation routing (`nextActionForProcurement`).

### Payout/accounting incident
1. set settlement freeze on impacted contract(s).
2. allow non-value progression where safe.
3. keep claims open unless a full emergency is required.

### Full emergency
1. call `pause()` on impacted contract(s).
2. communicate clearly to users that this is break-glass mode.
3. recover, patch, and then unpause in stages (emergency -> settlement -> intake).

### Recovery / unpause
Recommended order:
1. `unpause()` (exit break-glass emergency)
2. keep settlement freeze if accounting checks still pending
3. re-open settlement
4. re-open intake

