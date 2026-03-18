# Security Testing Runbook

Use deterministic installs before all checks:

```bash
npm ci
```

## Assurance tiers

### Fast local / PR-safe

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

The Foundry layer is the canonical property-testing layer for Prime. It is intended to catch the overwhelming majority of reachable state-machine, accounting, deadline, pause, and incentive bugs before external review. It does **not** replace an external audit. Instead, it narrows what auditors need to review by supplying reproducible handler-based invariant coverage, focused boundary fuzzing, hostile-hook testing, and explicit accounting assertions.

## Property-testing architecture

- `forge-test/harness/` contains Prime-only observability harnesses for jobs, procurements, applications, score commits, and ownership/pause state.
- `forge-test/fuzz/` contains focused campaigns for arithmetic boundaries, exact deadline edges, pause-safe clocks, hostile ENS hooks, reward-budget conservation, and two-step ownership behavior.
- `forge-test/invariant/` contains handler-based stateful fuzzing over `AGIJobManagerPrime` + `AGIJobDiscoveryPrime` with multi-actor random sequences, owner/admin interleavings, pause toggles, discovery fallback promotion, claim replay, and cross-contract flows.

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

## Replay and triage

Use deterministic profiles and replay the emitted seed directly. Recommended commands:

```bash
npm run forge:replay:prime
npm run forge:replay:ghost
FOUNDRY_PROFILE=soak forge test --match-path 'forge-test/invariant/*.t.sol' -vvvv
```

## High-value campaigns included

- `PrimeDeadlineBoundaryFuzz.t.sol` covers `deadline - 1`, `deadline`, `deadline + 1`, and pause-clock boundary behavior.
- `PrimeHookPauseOwnershipFuzz.t.sol` covers best-effort ENS hook failures, repeated pause/unpause cycles, under-quorum reward settlement, and discovery ownership transfer safety.
- `PrimeIncentiveAccountingFuzz.t.sol` stresses discovery validator reward accounting versus configured reward and bond budgets.
- `PrimeProtocolInvariants.t.sol` exercises broad state-machine and accounting invariants with randomized actors.
- `PrimeProtocolGhostInvariants.t.sol` adds a second handler with ghost accounting, terminal-transition counters, ownership/admin fuzzing, hostile hook toggles, claim tracking, and cross-contract cleanup assertions.

## Expected outcomes

- Truffle regression coverage continues to pass for legacy and Prime integration flows.
- Foundry fuzzing and invariants preserve manager/discovery solvency and state-machine coherence across weird sequences.
- Bytecode size and deploy-smoke checks remain green.
- Residual manual review can stay focused on economic design assumptions, governance/operator trust boundaries, and any logic not fully observable through current harnesses.
