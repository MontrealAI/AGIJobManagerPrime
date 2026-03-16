# Test Status

## Canonical Prime validation snapshot

This repository now treats Prime (`AGIJobManagerPrime` + `AGIJobDiscoveryPrime`) as the canonical production path.

### Commands and outcomes

- `npm ci` ✅
- `cd hardhat && npm ci` ✅
- `npm run test:prime:ci` ✅
  - runs Prime unit/integration flow (`test/prime.discovery-settlement.test.js`)
  - runs canonical Hardhat compile profile + Prime runtime size guard
  - runs Hardhat Prime deploy smoke (`hardhat/scripts/prime-deploy-smoke.js`)

### Prime size guard snapshot (canonical compiler profile)

From `npm run test:prime:ci`:

- `AGIJobManagerPrime runtime bytecode size: 24378 bytes`
- `AGIJobDiscoveryPrime runtime bytecode size: 18593 bytes`

Both are under the EIP-170 deployed runtime ceiling of 24,576 bytes.

### Notes

- Prime mainnet readiness is gated on the Hardhat compiler profile in `hardhat/hardhat.config.js` (optimizer enabled, `runs: 1`, `viaIR: true`, `evmVersion: shanghai`, stripped revert strings).
- Legacy Truffle-wide suites remain in-repo for compatibility/reference, but canonical release confidence comes from the Prime-first CI lane (`npm run test:prime:ci`).
