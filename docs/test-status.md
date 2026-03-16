# Test status (local Prime canonical lane)

This file records the latest local Prime-first run in this repository.

## Environment
- OS: Linux (container)
- Node: v20.x
- Solidity (Hardhat): 0.8.23

## Commands executed

```bash
npm ci
cd hardhat && npm ci
npm run test:prime:ci
```

## Result

All commands completed successfully.

`npm run test:prime:ci` includes:
1. Prime discovery + settlement tests (`test/prime.discovery-settlement.test.js`)
2. Hardhat canonical compile profile
3. Prime runtime size check
4. Prime deploy smoke check

## Prime runtime size snapshot

- `AGIJobManagerPrime`: `24378` bytes
- `AGIJobDiscoveryPrime`: `18593` bytes

Both are below EIP-170 runtime limit (`24576` bytes).
