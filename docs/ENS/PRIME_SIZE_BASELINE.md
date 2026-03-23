# Prime Size Baseline

## Goal

Keep `AGIJobManagerPrime` below the 24,576-byte EIP-170 runtime limit and avoid any unnecessary growth.

## Baseline rule

This remediation treats Prime as size-frozen by default. ENS authority, inspection, migration, repair, and finalization should stay outside Prime unless a smaller ENS-side alternative is impossible.

## Measurement commands

- `npm run test:size`
- `npm run test:size:benchmark`
- `node scripts/check-bytecode-size.js`

## Reporting rule

Record the following before any Prime runtime change is considered:

- runtime size
- runtime headroom
- initcode size
- initcode headroom

for:

- `AGIJobManagerPrime`
- `AGIJobDiscoveryPrime`
- `AGIJobCompletionNFT`
- `ENSJobPages`
- any new ENS-side helper contract

## Current implementation decision

This patch intentionally keeps Prime runtime behavior unchanged. The only required work is ENS-side plus tooling/docs, so Prime size should remain at the existing baseline once `npm run test:size` and `npm run test:size:benchmark` are re-run in a fully network-enabled build environment.
