# Mainnet Deployment Checklist (Prime Canonical)

This checklist is for **Prime** production deployment via the canonical Hardhat path in [`hardhat/README.md`](hardhat/README.md).
Legacy Truffle deployment notes are retained in [`docs/Deployment.md`](docs/Deployment.md) as reference-only.

## Preflight

- Confirm `hardhat/.env` has `MAINNET_RPC_URL`, `PRIVATE_KEY`, `FINAL_OWNER`, and `DEPLOY_CONFIRM_MAINNET`.
- Confirm deploy config values in `hardhat/deploy.config.example.js` are copied into your real deploy config and validated.
- Run compile and bytecode checks before any broadcast:
  - `cd hardhat && npm run compile`
  - `cd .. && npx truffle compile --all`
  - `node -e "const fs=require('fs');const a=JSON.parse(fs.readFileSync('hardhat/artifacts/contracts/AGIJobManagerPrime.sol/AGIJobManagerPrime.json'));const b=(a.deployedBytecode||'').replace(/^0x/,'');console.log('runtime',b.length/2);"`

## Dry-run then broadcast

- Dry-run mainnet plan first:
  - `cd hardhat && npm run deploy:prime:mainnet:dry-run`
- Broadcast mainnet only after review:
  - `cd hardhat && VERIFY=1 npm run deploy:prime:mainnet:live`

## Post-deploy verification and wiring checks

- Confirm deployment artifact exists in `hardhat/deployments/mainnet/`.
- Confirm artifact contains:
  - linked library addresses,
  - `AGIJobManagerPrime` and `AGIJobDiscoveryPrime` addresses,
  - `setDiscoveryModule` tx,
  - `completionNFT` address,
  - ownership transfer status.
- Re-run verification from artifact:
  - `cd hardhat && npm run verify:prime -- --network mainnet`
- Verify `setDiscoveryModule(discoveryAddress)` completed and addresses match deployment summary.

## Operational controls

- Transfer ownership to a multisig (e.g., Safe), not an EOA, unless your explicit policy says otherwise.
- Confirm pause/emergency controls and key custody runbook before opening production flows.
- Run Slither and full relevant tests before scaling funds at risk.

## Human security review gates

- Independent review of procurement scoring and fallback-promotion economics.
- Independent review of solvency accounting and dispute paths.
- Independent review of mainnet operational runbooks and incident-response paths.
