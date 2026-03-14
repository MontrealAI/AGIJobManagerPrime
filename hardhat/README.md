# Hardhat Operator Guide (Prime Canonical Deployment)

This `hardhat/` project is the canonical production deployment path for **AGIJobManagerPrime**:

- deploy linked Prime libraries
- deploy `AGIJobManagerPrime`
- deploy `AGIJobDiscoveryPrime`
- wire `setDiscoveryModule(discoveryAddress)`
- optionally transfer ownership to `FINAL_OWNER`
- optionally verify on Etherscan (`VERIFY=1`, default)

Legacy Truffle paths remain available, but are not the recommended path for Prime.

## Prime architecture (operator view)

- `AGIJobManagerPrime`: conservative settlement kernel (escrow, bonds, validation, challenge/dispute/finalization, accounting).
- `AGIJobDiscoveryPrime`: premium procurement layer (commit/reveal applications, shortlist, trial, validator score commit/reveal, winner designation, fallback promotion).

The Prime deployment script targets that architecture directly and does **not** deploy the legacy `AGIJobManager` by default.

## Quickstart

```bash
cd hardhat
npm ci
cp .env.example .env
npm run compile
```

## Required environment

- `MAINNET_RPC_URL`
- `SEPOLIA_RPC_URL`
- `PRIVATE_KEY`
- `ETHERSCAN_API_KEY`

Mainnet broadcast also requires:
- `DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT`

Optional:
- `FINAL_OWNER`
- `DEPLOY_CONFIG`
- `DRY_RUN=1`
- `VERIFY=0` (to skip verification)
- `CONFIRMATIONS` (default `3`)
- `VERIFY_DELAY_MS` (default `3500`)

## Deploy profile

Default profile file: `deploy.config.example.js`

Each network profile must define:

- `agiTokenAddress`
- `baseIpfsUrl`
- `ensAddress`
- `nameWrapperAddress`
- `rootNodes` (`bytes32[4]`)
- `merkleRoots` (`bytes32[2]`)
- `finalOwner`

Override profile path:

```bash
DEPLOY_CONFIG=./my.deploy.config.js
```

## Commands

Compile:

```bash
npm run compile
```

### Sepolia (recommended path)

Dry-run:

```bash
DRY_RUN=1 npm run deploy:prime:sepolia
```

Broadcast:

```bash
npm run deploy:prime:sepolia
```

### Mainnet (recommended path)

Dry-run:

```bash
DRY_RUN=1 DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT npm run deploy:prime:mainnet
```

Broadcast:

```bash
DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT npm run deploy:prime:mainnet
```

## Deployment artifacts

Written to `hardhat/deployments/<network>/`:

- `deployment.prime.<chainId>.<blockNumber>.json`
- `solc-input.json`
- `verify-targets.prime.json`

The deployment receipt includes constructor inputs, library links, discovery wiring tx, ownership transfer status, and verification results.

## Premium job entrypoints for integrators

`AGIJobDiscoveryPrime` exposes:

- `quoteProcurementBudget(...)`
- `createPremiumJobWithDiscovery(...)`
- `attachProcurementToExistingJob(...)`

`AGIJobManagerPrime` still supports ordinary first-come job creation for non-premium flow.
