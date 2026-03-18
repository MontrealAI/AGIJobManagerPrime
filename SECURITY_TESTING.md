# Security Testing Runbook

Use deterministic installs before all checks:

```bash
npm ci
```

## Prime assurance tiers

### Fast local developer loop

```bash
npm run forge:fuzz
npm run forge:invariant
```

### CI-strength Prime property suite

```bash
npm run test:prime:ci
```

This tier runs:

- existing Prime Truffle regression coverage,
- Foundry-focused Prime fuzz campaigns,
- handler-based Prime invariants over the real manager/discovery pair,
- deploy smoke, and
- bytecode size gates.

### Heavy soak / audit-prep runs

```bash
npm run forge:soak
npm run test:prime:security
```

Use the soak profile for nightly/manual campaigns where you want deeper sequence exploration and longer deadline/pause searches. It is intended to materially narrow external audit scope by surfacing weird state-machine, accounting, and pause-clock failures earlier; it does **not** replace external review.

## Foundry property-testing architecture

The Prime Foundry layer is the canonical high-assurance property suite and is organized as:

- `forge-test/fuzz/`: focused arithmetic, ownership, URI, deadline, and boundary fuzz tests.
- `forge-test/harness/`: Prime-only harnesses plus stateful handler utilities.
- `forge-test/invariant/`: multi-actor handler-based invariants over real `AGIJobManagerPrime` and `AGIJobDiscoveryPrime` deployments.

### Current Prime invariant coverage focus

The handler/invariant layer is built to search for failures in:

- manager token conservation vs `lockedEscrow`, `lockedAgentBonds`, `lockedValidatorBonds`, and `lockedDisputeBonds`,
- discovery solvency vs observed locked stakes/bonds plus `claimable`,
- state-machine contradictions such as completed+expired, completed+disputed, or accepted/trial states out of order,
- snapshot immutability for live manager jobs after completion request,
- validator/dispute settlement one-shot behavior,
- helper-view truthfulness such as `nextActionForProcurement` and `isWinnerFinalizable`,
- fallback promotion one-shot behavior, and
- best-effort ENS hook failures not corrupting settlement-critical accounting.

### Replaying failures

Always keep the exact failing seed/profile from Forge output. Replay with the same profile and a fixed seed, for example:

```bash
FOUNDRY_PROFILE=ci forge test --match-test invariant_managerSolventAgainstLockedBuckets --seed <seed>
FOUNDRY_PROFILE=soak forge test --match-path forge-test/invariant/PrimeProtocolInvariants.t.sol --seed <seed> -vvvv
```

## Required checks

```bash
npm ci && npm run test:prime:ci
FOUNDRY_PROFILE=ci forge test --match-path "forge-test/fuzz/*.t.sol"
FOUNDRY_PROFILE=ci forge test --match-path "forge-test/invariant/*.t.sol"
slither . --config-file slither.config.json
```

## Expected outcomes

- Prime Truffle regression suite passes.
- Foundry Prime fuzz + invariants pass without accounting or state-machine invariant violations.
- Deploy smoke and bytecode size gates remain green.
- Slither reports no unexpected High/Medium issues on production contracts.

## Echidna

This repository relies on Foundry invariant tests as the primary property-testing layer.

## Slither configuration notes

`slither.config.json` suppresses a small set of noisy detectors for this repository:

- `reentrancy-*` and `reentrancy-balance`: core settlement/auth entrypoints are already guarded (`nonReentrant`) and covered by regression/invariant suites.
- `divide-before-multiply`: used in bounded bond/reward math with explicit caps and dedicated tests.
- `mapping-deletion`: expected for deleting job structs containing mappings after terminal settlement.
- `uninitialized-local`: false positives on Solidity default-initialized locals.
- `unused-return`: intentional best-effort ENS/namewrapper interactions where failures must not brick core flows.
