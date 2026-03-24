# Current `main` baseline audit (ENS subsystem)

Date: 2026-03-24

## Scope audited
- `contracts/ens/ENSJobPages.sol`
- `contracts/ens/ENSJobPagesInspector.sol`
- `contracts/interfaces/IAGIJobManagerPrimeViewV1.sol`
- `contracts/AGIJobManagerPrime.sol`
- `hardhat/scripts/deploy-ens-job-pages.js`
- `scripts/check-bytecode-size.js`
- `scripts/ens/phase0-mainnet-snapshot.mjs`
- `docs/ENS/ENS_JOB_PAGES_OVERVIEW.md`
- `docs/DEPLOYMENT/ENS_JOB_PAGES_MAINNET_REPLACEMENT.md`
- `hardhat/README.md`
- `PRIME_BLOCKER_VERIFICATION_MEMO.md`

## Already merged and correct
- Preview (`previewJobEns*`) and effective (`effectiveJobEns*`) identity are separated.
- Authority snapshots store immutable label+root-version for historical stability.
- Compatibility getters (`jobEns*`) correctly degrade to preview pre-authority and effective post-authority.
- Prime hook ABI remains `handleHook(uint8,uint256)` and manager-side hook calls are low-level + non-blocking.
- Runtime capability detection exists in ENS helper (`_managerSupportsViewV1` + fallback read selectors).
- Repair/replay surfaces already exist and are owner-gated.
- Inspector exposes manager compatibility mode and auth-read truthfulness flags.
- Deployment script enforces explicit `JOB_MANAGER` on mainnet and root namehash consistency.
- Size checker enforces runtime and initcode for Prime + ENSJobPages + ENSJobPagesInspector.

## Already merged but incomplete
- Legacy unmanaged-node migration was only partially covered; `_createJobPage` previously reverted when authoritative node existed but was unmanaged.
- Root-version observability exposed only count/current-id; no direct rootVersion info getter for root-id driven repair.

## Dangerous mismatches
- `PRIME_BLOCKER_VERIFICATION_MEMO.md` bytecode numbers drift from current artifacts and must be refreshed from live test output.

## Mandatory current-state questions (answers)
1. Does current `main` auto-issue effective identity under unchanged Prime? **Yes** (fallback create path uses `jobEmployerOf` and snapshots authority).
2. Does current `main` solve legacy unmanaged-node adoption? **Not fully before this patch** (existing unmanaged authoritative node could revert in create/replay).
3. Does current `main` expose enough root-version state for safe multi-root repair? **Partially** (count/current existed; direct per-version info missing).
4. Does current `main` make ENS-side bytecode limits fail-fast in default deployment path? **Yes** for current deployed ENS artifacts via `check-bytecode-size.js` invoked by deploy preflight.
5. Which changes are necessary and why Prime changes avoidable? **ENS-side adoption + root-version read observability only; Prime runtime change avoidable.**
