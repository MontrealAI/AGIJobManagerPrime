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

- `forge-test/harness/` contains Prime-only harnesses that expose read-only observability for jobs, procurements, applications, score commits, pause clocks, and completion-NFT state.
- `forge-test/fuzz/` contains focused campaigns for deadline boundaries, pause-safe clocks, validator incentive accounting, and utility/math edge conditions.
- `forge-test/invariant/` contains the canonical handler-based stateful fuzzing layer over real `AGIJobManagerPrime` + real `AGIJobDiscoveryPrime`, with randomized owner actions, pause toggles, hostile ENS hook targets, multi-actor flows, and ghost settlement counters.

## Prime invariants now emphasized

- Manager token conservation against escrow, agent bonds, validator bonds, and dispute bonds.
- Discovery token conservation against still-locked stakes/bonds/budgets plus total claimable balances.
- One-shot settlement tracking for dispute bonds, validator bonds, agent bonds, and discovery score bonds.
- Snapshot immutability for live manager jobs once assignment occurs.
- Cross-contract linkage coherence between procurements and Prime jobs.
- Pause-clock/helper-view coherence so helper views do not advertise impossible actions.
- Completion-NFT issuance restricted to true completion paths only.
- Best-effort ENS job-page hooks exercised under healthy and hostile targets without settlement-accounting corruption claims.

## Replay and triage

Use deterministic Foundry profiles and replay the emitted seed directly. Recommended commands:

```bash
FOUNDRY_PROFILE=ci forge test --match-path forge-test/invariant/*.t.sol -vvvv
FOUNDRY_PROFILE=soak forge test --match-path forge-test/invariant/*.t.sol --match-test invariant_ -vvvv
```

## Expected outcomes

- Truffle regression coverage passes for legacy and Prime integration flows.
- Foundry fuzzing and invariants preserve manager/discovery solvency and state-machine coherence.
- Bytecode size and deploy-smoke checks remain green.
- Slither stays focused on residual manual review areas rather than already-proven accounting invariants.
