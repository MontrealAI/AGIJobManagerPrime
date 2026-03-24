# Prime ↔ ENS Compatibility Gap (Current main)

## Executive summary

`AGIJobManagerPrime` remains intentionally lean and selector-stable. It does not expose V1 rich ENS view getters, and it does not emit typed push-hook calls. Production correctness therefore depends on:

1. legacy `handleHook(uint8,uint256)` compatibility;
2. ENS-side authority snapshot correctness;
3. keeper-assisted replay/repair for metadata where rich manager views are unavailable.

## Gap classification

- **Solved in-contract:** authority model, historical identity stability, root versioning, compatibility getters, repair/replay endpoints.
- **Gap at cutover/tooling layer:** script preflight previously did not enforce semantic compatibility before wiring or locking.

## Patched in this change set

- Added shared Hardhat preflight library to classify manager mode (`rich-v1-view-compatible`, `lean-handleHook-compatible`, `none`) and hook callability.
- `deploy-ens-job-pages.js` now prints compatibility mode and refuses `LOCK_CONFIG` in keeper-required / unresolved mode.
- `deploy.js` now preflights ENS target before `setEnsJobPages(...)`, including code existence, legacy hook callability, and target-manager alignment.

## Operating modes

- **Rich mode (fully automatic metadata path):** no keeper required for spec/completion hydration.
- **Lean mode (current Prime reality):** authoritative node issuance works, but keeper-assisted metadata repair/replay remains required.
- **None mode:** refuse cutover.
