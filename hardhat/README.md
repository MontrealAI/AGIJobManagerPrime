# Hardhat Operator Guide (Canonical Prime Deployment Path)

This `hardhat/` project is the canonical deployment workflow for **AGIJobManagerPrime + AGIJobDiscoveryPrime**.

Prime architecture:
- `AGIJobManagerPrime`: settlement-first kernel (escrow, bonds, disputes, solvency, conservative controls).
- `AGIJobDiscoveryPrime`: premium procurement-first discovery (commit/reveal applications, shortlist, trial scoring, winner handoff).

## What `scripts/deploy.js` does

1. Deploy linked libraries: `UriUtils`, `BondMath`, `ReputationMath`, `ENSOwnership`.
2. Deploy `AGIJobManagerPrime`.
3. Deploy `AGIJobDiscoveryPrime(settlementAddress)`.
4. Call `AGIJobManagerPrime.setDiscoveryModule(discoveryAddress)`.
5. If deployer != final owner, transfer manager ownership immediately and initiate discovery two-step ownership (`transferOwnership`) requiring later `acceptOwnership()`.
6. Optionally verify contracts (`VERIFY=1`) on Etherscan.
7. Preflight-check AGIJobManagerPrime and AGIJobDiscoveryPrime runtime/initcode (including ABI-encoded constructor args) against mainnet limits before broadcast.
8. Read and persist the manager-created completion NFT address for operators and indexers.
9. Write deployment artifacts and verify-target manifests.

## Mainnet safety posture

- Explicit confirmation gate on chainId 1:
  - `DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT`
- Config validation before any broadcast.
- Dry-run mode:
  - `DRY_RUN=1`
- `ENS_JOB_PAGES` (optional ENSJobPages-compatible target wired via `setEnsJobPages`)
- `ENS_JOB_PAGES` wiring now runs semantic preflight before `setEnsJobPages(...)`:
  - target must expose `validateConfiguration()`
  - target `jobManager()` must match the just-deployed manager address
  - manager compatibility mode must be `rich` or `lean` (never `none`)
- `JOB_MANAGER` is mandatory for `scripts/deploy-ens-job-pages.js` on Ethereum mainnet; the script now refuses stale/implicit defaults.
- Plan summary printed before execution, including Prime bytecode/runtime headroom.
- Network/chainId mismatch protection (mainnet=1, sepolia=11155111).

## Compiler source of truth

- Canonical compiler settings are defined only in `hardhat/hardhat.config.js` and consumed by `scripts/deploy.js` for plan output.
- Deploy scripts do not carry separate hard-coded compiler profiles.

## Environment setup

```bash
cd hardhat
npm ci
cp .env.example .env
```

Required environment variables:
- `MAINNET_RPC_URL`
- `SEPOLIA_RPC_URL`
- `PRIVATE_KEY`
- `ETHERSCAN_API_KEY` (needed for `VERIFY=1`)

Common deploy controls:
- `FINAL_OWNER` (EOA or multisig)
- `DEPLOY_CONFIG` (path override)
- `CONFIRMATIONS` (default `3`)
- `VERIFY_DELAY_MS` (default `3500`)
- `VERIFY=1` (set `0` or unset to skip verification)
- `DRY_RUN=1`
- `ENS_JOB_PAGES` (optional ENSJobPages-compatible target wired via `setEnsJobPages`)
- `JOB_MANAGER` is mandatory for `scripts/deploy-ens-job-pages.js` on Ethereum mainnet; the script now refuses stale/implicit defaults.
- `DEPLOYMENT_ARTIFACT` (optional; used by `scripts/verify-prime.js`)
- Pass `--network <mainnet|sepolia>` directly to `npm run verify:prime`

Profile override knobs (for reproducible bytecode benchmarking only):
- `AGI_PRIME_OPTIMIZER_RUNS` (default `1`)
- `AGI_PRIME_VIA_IR` (`1`/`0`, default `1`)


Post-deploy ownership handoff:
- Deployer transfers `AGIJobManagerPrime` ownership immediately to `FINAL_OWNER`.
- Deployer initiates `AGIJobDiscoveryPrime` transfer; `FINAL_OWNER` must call `acceptOwnership()`.
- If discovery pending owner was wrong, current owner can call `cancelOwnershipTransfer()`.

Pause controls:
- Manager: `pause()/unpause()` for intake stop, plus `setSettlementPaused(bool)` for settlement freeze. Manager-owned windows (selection/application/checkpoint/completion/challenge/stale-dispute) are evaluated on pause-adjusted effective time.
- Discovery: `setIntakePaused(bool)` blocks only new procurement attachment/creation, while in-flight procurements continue. `pause()/unpause()` is break-glass and now freezes procurement phase clocks (commit/reveal/accept/trial/score windows) until unpause. Settlement freeze follows manager `setSettlementPaused(bool)` for winner/fallback settlement-coupled actions.

## Deploy config

Default config file: `hardhat/deploy.config.example.js`

Per-network required fields:
- `agiTokenAddress`
- `baseIpfsUrl`
- `ensConfig` = `[ensRegistry, nameWrapper]`
- `rootNodes` (4 bytes32)
- `merkleRoots` (2 bytes32)
- `finalOwner`

## Commands


Benchmark runtime bytecode profiles (compares viaIR/runs matrix and prints EIP-170 margin):

```bash
cd ..
npm run test:size:benchmark
```

Canonical production profile remains `optimizer: enabled, runs=1, viaIR=true` unless benchmark evidence and passing tests justify a change.

Compile:

```bash
cd hardhat
npm run compile
```

Dry-run mainnet plan:

```bash
cd hardhat
npm run deploy:prime:dry-run:mainnet
```

Broadcast mainnet deployment:

```bash
cd hardhat
VERIFY=1 npm run deploy:prime:mainnet
```

Deploy to Sepolia:

```bash
cd hardhat
VERIFY=1 npm run deploy:prime:sepolia
```

Verify deployed contracts (libraries + manager + discovery + completion NFT) from the latest deployment artifact:

```bash
cd hardhat
npm run verify:prime -- --network mainnet
```

Or verify a specific artifact:

```bash
cd hardhat
DEPLOYMENT_ARTIFACT=deployments/mainnet/deployment.prime.1.<block>.json npm run verify:prime -- --network mainnet
```

## Prime entrypoints for operators

Discovery exposes three canonical premium helpers:
- `quoteProcurementBudget(...)`
- `createPremiumJobWithDiscovery(...)`
- `attachProcurementToExistingJob(...)`

`attachProcurementToExistingJob(...)` is only valid for employer-called upgrades on jobs that are still unassigned and configured for SelectedAgentOnly intake; OpenFirstCome jobs are not eligible and will revert.

Discovery also exposes permissionless automation helpers after deployment:
- `advanceProcurement(procurementId)` for staged timeout-driven progression (shortlist finalization -> winner finalization -> fallback promotion).
- `getAutonomyStatus(procurementId)` / `nextActionForProcurement(procurementId)` for keeper/bot routing.

Operational split:
- Ordinary/open jobs can be created directly on `AGIJobManagerPrime`.
- Premium jobs should be created through discovery so procurement completes before assignment.
- Discovery then assigns the designated winner into settlement and supports fallback promotion if the winner stalls.

## Output artifacts

Deploy outputs are written to `hardhat/deployments/<network>/`:
- `deployment.prime.<chainId>.<blockNumber>.json`
- `solc-input.json`
- `verify-targets.prime.json`

Deployment summaries also print `completionNFT` (instantiated by `AGIJobManagerPrime`) and explorer links when available.

## Legacy compatibility

- Legacy settlement contract `contracts/AGIJobManager.sol` remains in-repo.
- `scripts/deploy-ens-job-pages.js` remains available for additive ENSJobPages operations.
- Prime deploy script is now the canonical default for this repository.


Deployment smoke check (local hardhat):

```bash
cd hardhat
npm run deploy:prime:smoke
```

## Prime ENS wiring (optional, post-deploy)

Prime settlement works without ENS wiring. If operators want ENS-backed public job pages, the current verified mainnet manager target is `0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e` and the observed legacy ENS helper target is `0x97E03F7BFAC116E558A25C8f09aEf09108a2779d`.

Recommended wiring flow:

1. Run `node ../scripts/ens/audit-mainnet.ts` and `node ../scripts/ens/phase0-mainnet-snapshot.mjs` first.
2. Deploy/prepare the replacement `ENSJobPages` target with `scripts/deploy-ens-job-pages.js` and an explicit `JOB_MANAGER=<prime-or-legacy-manager>` on mainnet.
   - script prints machine-readable compatibility posture (`managerMode`, `keeperRequired`, etc).
   - `LOCK_CONFIG=1` is refused in unsafe modes and, for keeper-required mode, requires explicit `ALLOW_LOCK_WITH_KEEPER=1`.
3. Confirm wrapped-root approvals and `validateConfiguration()==0`.
4. Call `AGIJobManagerPrime.setEnsJobPages(target)` as manager owner.
5. Validate one canary create flow plus one explicit repair flow from `node ../scripts/ens/repair-from-logs.ts`.

Lifecycle hooks are best-effort and bounded, so settlement remains authoritative even if ENS/page calls fail. Under unchanged Prime wiring, authoritative ENS identity can still be issued automatically, but missing spec/completion metadata may require explicit ENS-side repair functions and log-driven scripts; do not rely on stale/nonexistent manager-side sync helpers.
