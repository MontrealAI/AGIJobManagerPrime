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
5. Optionally transfer ownership of both contracts to `FINAL_OWNER`.
6. Optionally verify contracts (`VERIFY=1`) on Etherscan.
7. Read and persist the manager-created completion NFT address for operators and indexers.
8. Write deployment artifacts and verify-target manifests.

## Mainnet safety posture

- Explicit confirmation gate on chainId 1:
  - `DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT`
- Config validation before any broadcast.
- Dry-run mode:
  - `DRY_RUN=1`
- Plan summary printed before execution.
- Network/chainId mismatch protection (mainnet=1, sepolia=11155111).

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
- `FINAL_OWNER`
- `DEPLOY_CONFIG` (path override)
- `CONFIRMATIONS` (default `3`)
- `VERIFY_DELAY_MS` (default `3500`)
- `VERIFY=1` (set `0` or unset to skip verification)
- `DRY_RUN=1`
- `DEPLOYMENT_ARTIFACT` (optional; used by `scripts/verify-prime.js`)
- Pass `--network <mainnet|sepolia>` directly to `npm run verify:prime`

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

## Prime ENS wiring status

ENSJobPages parity remains an explicit Prime requirement, but integration is currently being reworked to preserve strict EIP-170 deployability bounds for `AGIJobManagerPrime`.

Use legacy ENS runbooks for current operator flows until the Prime ENS path is reintroduced in a size-safe periphery pattern.
