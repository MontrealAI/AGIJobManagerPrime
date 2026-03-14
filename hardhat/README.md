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
7. Write deployment artifacts and verify-target manifests.

## Mainnet safety posture

- Explicit confirmation gate on chainId 1:
  - `DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT`
- Config validation before any broadcast.
- Dry-run mode:
  - `DRY_RUN=1`
- Plan summary printed before execution.

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
DRY_RUN=1 DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT npm run deploy:prime:mainnet
```

Broadcast mainnet deployment:

```bash
cd hardhat
DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT VERIFY=1 npm run deploy:prime:mainnet
```

Deploy to Sepolia:

```bash
cd hardhat
VERIFY=1 npm run deploy:prime:sepolia
```

## Output artifacts

Deploy outputs are written to `hardhat/deployments/<network>/`:
- `deployment.prime.<chainId>.<blockNumber>.json`
- `solc-input.json`
- `verify-targets.prime.json`

## Legacy compatibility

- Legacy settlement contract `contracts/AGIJobManager.sol` remains in-repo.
- `scripts/deploy-ens-job-pages.js` remains available for additive ENSJobPages operations.
- Prime deploy script is now the canonical default for this repository.
