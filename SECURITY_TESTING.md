# Security Testing Runbook

Use deterministic installs before all checks:

```bash
npm ci
```

## Assurance tiers

### Fast local / PR-safe

```bash
npm run test:prime:pr
```

This runs the canonical Prime Foundry property layer at the fast profile:

```bash
npm run forge:fuzz
npm run forge:invariant
```

### CI assurance tier

```bash
npm run test:prime:ci
```

### Heavy soak / audit-prep tier

```bash
npm run forge:soak
# or the heaviest manual profile
FOUNDRY_PROFILE=audit forge test --match-path 'forge-test/invariant/*.t.sol'
```

The Foundry layer is the canonical property-testing layer for Prime. It is intended to catch the overwhelming majority of reachable state-machine, accounting, deadline, pause, and incentive bugs before external review. It does **not** replace an external audit. Instead, it narrows what auditors need to review by supplying reproducible handler-based invariant coverage, focused boundary fuzzing, hostile-hook testing, explicit accounting assertions, and pause-clock proofs that are hard to cover with example tests alone.

## Property-testing architecture

### 1. Focused fuzz campaigns (`forge-test/fuzz/`)

- `PrimeDeadlineBoundaryFuzz.t.sol` covers `deadline - 1`, `deadline`, `deadline + 1`, repeated tiny warps, and pause-clock deadline edges.
- `PrimeHookPauseOwnershipFuzz.t.sol` covers best-effort ENS hook failures, repeated pause/unpause cycles, reward-budget conservation, and ownership-transfer safety.
- `PrimeIncentiveAccountingFuzz.t.sol` covers discovery validator reward accounting under different reveal counts and score distributions.
- `PrimeLibraryAndOwnershipFuzz.t.sol` fuzzes `BondMath`, `ReputationMath`, `UriUtils`, and `BusinessOwnable2Step` boundaries.
- `PrimeManagerSettlementFuzz.t.sol` stress-tests manager validator voting paths: zero-vote, low-quorum, tie, approval-majority, disapproval-majority, challenge-window timing, and one-shot dispute resolution.

### 2. Stateful handler-based invariants (`forge-test/invariant/`)

- `PrimeProtocolInvariants.t.sol` provides broad multi-actor state-machine coverage across manager + discovery.
- `PrimeProtocolGhostInvariants.t.sol` adds shadow accounting, one-shot settlement counters, hostile hook toggles, claim tracking, and terminal cleanup assertions.
- `PrimePauseDeadlineInvariants.t.sol` is a dedicated pause/deadline suite proving that paused time is monotonic, procurement baselines are pinned at creation time, and effective procurement time freezes across pause windows instead of silently crossing deadlines.

### 3. Harness / oracle layer (`forge-test/harness/`)

- `AGIJobManagerPrimeHarness.sol` exposes stable observability for live-job snapshots, timing state, and validator participation.
- `AGIJobDiscoveryPrimeHarness.sol` now exposes paused-seconds and effective-timestamp views in addition to procurement/application/score state so pause/deadline invariants can reason about clocks without touching production logic.

## Core ghost-accounting assertions

The ghost handler continuously recomputes independent expected totals from per-job and per-procurement state instead of trusting aggregate counters alone.

Tracked buckets:

- manager escrow
- manager agent bonds
- manager validator bonds
- manager dispute bonds
- discovery locked application stakes
- discovery locked finalist stakes
- discovery locked score bonds
- discovery reserved stipend / validator reward budgets
- discovery claimable totals and observed claim payouts

These ghost buckets back invariants for:

- token conservation and solvency
- no claimable drift
- one-shot settlement / no double-finalization
- pause-baseline monotonicity
- completion-NFT mint gating
- terminal cleanup of stakes and validator score bonds

## High-value invariant categories covered

- manager token conservation versus escrow + bond buckets
- discovery token conservation versus locked stakes + reserved budgets + claimables
- no double distribution of validator bonds, dispute bonds, or discovery score bonds
- job state monotonicity: no `completed && expired`, no `completed && disputed`, no snapshot mutation after assignment
- discovery state monotonicity: shortlisted implies revealed, accepted implies shortlisted, trial implies accepted, winner/cancel paths are one-shot
- pause/deadline safety: paused time cannot advance effective procurement time, and procurements created after prior pauses inherit the correct baseline
- ownership/emergency-control safety: pause toggles, intake pause, settlement pause, two-step ownership transfer, and renounce guards
- best-effort ENS hook safety: hostile hooks must never corrupt settlement-critical accounting

## Replay and triage

Use deterministic profiles and replay the emitted seed directly. Recommended commands:

```bash
npm run forge:replay:prime
npm run forge:replay:ghost
npm run forge:invariant:clock
FOUNDRY_PROFILE=soak forge test --match-path 'forge-test/invariant/*.t.sol' -vvvv
```

When Foundry reports a failing invariant seed, rerun the exact profile with the same seed and add `-vvvv` for the shrunk counterexample trace.

## Expected outcomes

- Truffle regression coverage continues to pass for legacy and Prime integration flows.
- Foundry fuzzing and invariants preserve manager/discovery solvency and state-machine coherence across weird sequences.
- Bytecode size and deploy-smoke checks remain green.
- Residual manual review can stay focused on economic design assumptions, governance/operator trust boundaries, and any logic not fully observable through current harnesses.
