# Prime Size Baseline

## Goal

Keep `AGIJobManagerPrime` below the 24,576-byte EIP-170 runtime limit and avoid any unnecessary growth.

## Baseline rule

This remediation treats Prime as size-frozen by default. ENS authority, inspection, migration, repair, and finalization should stay outside Prime unless a smaller ENS-side alternative is impossible.

## Measurement commands (executed 2026-03-24)

- `npm run test:size`
- `npm run test:size:benchmark`
- `npm run test:prime:deploy-smoke`

## Current measured sizes (2026-03-24)

| Contract | Runtime bytes | Runtime headroom vs 24,576 | Initcode bytes | Initcode headroom vs 49,152 |
|---|---:|---:|---:|---:|
| `AGIJobManagerPrime` | 24,472 | 104 | 29,972 | 19,180 |
| `AGIJobDiscoveryPrime` | 24,505 | 71 | 25,106 | 24,046 |
| `AGIJobCompletionNFT` | 3,334 | 21,242 | 4,177 | 44,975 |
| `ENSJobPages` | 24,560 | 16 | 27,350 | 21,802 |
| `ENSJobPagesInspector` | 7,269 | 17,307 | 7,296 | 41,856 |

## Benchmark result

`npm run test:size:benchmark` reconfirmed the production-safe profile remains `viaIR=true, runs=1` with:

- `AGIJobManagerPrime = 24,472`
- `AGIJobDiscoveryPrime = 24,505`

and that higher optimizer runs would violate Prime/Discovery EIP-170 safety margins.

## Current implementation decision

Prime runtime behavior remains unchanged in this remediation. ENS authority truthfulness, compatibility signaling, and repairability are handled ENS-side plus scripts/docs/runbooks.
