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
- **Discovery intake pause** (`setIntakePaused(bool)`): blocks only new procurement/job attachment exposure; in-flight procurements keep progressing.
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
| create premium procurement / attach procurement | blocked | allowed | blocked |
| commit/reveal applications, finalist acceptance, trial submit, score commit/reveal | allowed (for existing procurements) | allowed | blocked |
| winner finalization / fallback promotion / procurement cancel-unwind | allowed | conditional: neutral closeout allowed, manager-linked winner assignment blocked | blocked |
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



## Discovery pause-safe timing policy

Principle: **pause means everyone waits safely**.

Implementation details:
- Discovery keeps global paused-time accounting (`pauseStartedAt`, `pausedSecondsAccumulated`).
- Each procurement snapshots a `pauseSecondsBaseline` at creation.
- Time-gated phases evaluate an **effective procurement clock**: `block.timestamp - (globalPausedSecondsNow - pauseSecondsBaseline)`.
- Result: commit/reveal/accept/trial/score windows do not burn while discovery is paused, including repeated pause/unpause cycles.

User-facing policy decisions:
- Intake pause does **not** block in-flight procurement actions; it only blocks new exposure (`createPremiumJobWithDiscovery`, `attachProcurementToExistingJob`).
- Full discovery pause blocks writes, but affected procurement windows are frozen and resume fairly on unpause.
- `claim()` stays live during intake pause and settlement freeze.
- If manager settlement is frozen, discovery helpers return settlement-blocked status (for winner/fallback operations) while still exposing claimability and safe waiting states.
- `finalizeWinner` remains available under manager settlement freeze only when no designatable winner exists (neutral closeout path). If a winner can be assigned into manager, finalization waits safely for manager pause/freeze to clear.
- `nextActionForProcurement` surfaces linked-manager blockers with explicit strings: `settlement_paused` (manager broad pause) and `linked_settlement_frozen` (manager settlement freeze when winner designation would be required).

### Front-end UX spec (calm/respectful wording)
- Banner when discovery is fully paused: **"Discovery is temporarily paused. Your deadline is safely frozen and will resume after unpause."**
- Banner when intake paused only: **"New procurements are temporarily paused. Existing procurements continue normally."**
- Banner when settlement freeze active: **"Settlement is temporarily frozen. Existing claim balances remain withdrawable; winner assignment actions wait safely."**
- Countdown rule: display effective-time countdown (exclude paused duration), and show `Paused` badge while full pause is active.
- Claim state language: **"Claim available now"** whenever `canClaim(account) > 0` regardless of intake pause.
