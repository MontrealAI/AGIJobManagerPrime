# Security Testing Runbook

Use deterministic installs before all checks:

```bash
npm ci
cd hardhat && npm ci && cd ..
```

## Assurance tiers

### Fast local developer loop

```bash
npm run test:prime:unit
npm run forge:fuzz
```

### CI-grade property testing

```bash
npm run test:prime:ci
```

This tier keeps the legacy Prime regression tests, Foundry fuzz suites, Foundry handler-based invariants, the bytecode-size gate, and the Hardhat deploy-smoke path in one reproducible command.

### Soak / nightly / audit-prep runs

```bash
npm run forge:soak
npm run test:prime:security
```

Use the soak tier before releases, after touching pause/deadline/accounting logic, and when preparing material for external reviewers. It is intentionally heavier than CI.

## Foundry replay and triage

When Foundry reports a failing fuzz or invariant seed, replay it directly with the same profile and seed. Typical examples:

```bash
FOUNDRY_PROFILE=ci forge test --match-test invariant_managerTokenConservation --seed <SEED>
FOUNDRY_PROFILE=ci forge test --match-path forge-test/invariant/prime/PrimeArchitectureInvariants.t.sol --seed <SEED> -vvvv
FOUNDRY_PROFILE=soak forge test --match-path forge-test/fuzz/prime/PrimeDeadlineBoundaryFuzz.t.sol --seed <SEED> -vvvv
```

The new Prime property layer is designed to narrow external audit scope by producing reproducible evidence about:

- manager/discovery token conservation,
- locked-vs-claimable accounting,
- pause-clock correctness,
- manager/discovery state-machine monotonicity,
- multi-actor weird-sequence safety,
- best-effort ENS hook resilience,
- validator incentive settlement envelopes.

It does **not** replace an external audit.

## Required checks

```bash
npm run test:prime:ci
npm run forge:soak
slither . --config-file slither.config.json
```

## Expected outcomes

- Prime Truffle regressions pass.
- Foundry Prime fuzz + invariant suites pass without accounting or state-machine violations.
- Bytecode size and deploy-smoke checks stay green.
- Slither reports no High/Medium issues on project contracts.

## Slither configuration notes

`slither.config.json` suppresses a small set of noisy detectors for this repository:

- `reentrancy-*` and `reentrancy-balance`: core settlement/auth entrypoints are already guarded (`nonReentrant`) and covered by regression/invariant suites.
- `divide-before-multiply`: used in bounded bond/reward math with explicit caps and dedicated tests.
- `mapping-deletion`: expected for deleting job structs containing mappings after terminal settlement.
- `uninitialized-local`: false positives on Solidity default-initialized locals.
- `unused-return`: intentional best-effort ENS/namewrapper interactions where failures must not brick core flows.
