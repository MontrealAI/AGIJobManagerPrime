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
```

The Foundry layer is the canonical property-testing layer for Prime. It is intended to catch the overwhelming majority of reachable state-machine, accounting, deadline, pause, and incentive bugs before external review. It does **not** replace an external audit. Instead, it narrows what auditors need to review by supplying reproducible handler-based invariant coverage, focused boundary fuzzing, and explicit accounting assertions.

## Property-testing architecture

- `forge-test/harness/` contains Prime-only harnesses that expose read-only observability for jobs, procurements, applications, and score commits.
- `forge-test/fuzz/` contains focused campaigns for deadline boundaries, pause-safe clocks, and discovery incentive accounting.
- `forge-test/invariant/` contains handler-based stateful fuzzing over `AGIJobManagerPrime` + `AGIJobDiscoveryPrime` with owner actions, pause toggles, realistic actor roles, and cross-contract flows.

## Replay and triage

Use deterministic Foundry profiles and replay the emitted seed directly. Recommended commands:

```bash
FOUNDRY_PROFILE=ci forge test --match-contract PrimeProtocolInvariants -vvvv
FOUNDRY_PROFILE=ci forge test --match-contract PrimeProtocolGhostInvariants -vvvv
FOUNDRY_PROFILE=soak forge test --match-path forge-test/invariant/*.t.sol --match-test invariant_ -vvvv
```

## Expected outcomes

- Truffle regression coverage passes for legacy and Prime integration flows.
- Foundry fuzzing and invariants preserve manager/discovery solvency and state-machine coherence.
- Bytecode size and deploy-smoke checks remain green.
- Slither stays focused on residual manual review areas rather than already-proven accounting invariants.


## Added audit-grade campaigns

- `PrimeLibraryAndOwnershipFuzz.t.sol` fuzzes `BondMath`, `ReputationMath`, `UriUtils`, and `BusinessOwnable2Step` boundary behavior.
- `PrimeProtocolGhostInvariants.t.sol` adds a second stateful handler with ghost accounting, hostile ENS hook toggles, claim tracking, pause fuzzing, and manager/discovery cross-checks.
- The ghost suite is intended to provide hard evidence for conservation, monotonicity, pause-clock correctness, one-shot settlement, and completion-NFT gating.
