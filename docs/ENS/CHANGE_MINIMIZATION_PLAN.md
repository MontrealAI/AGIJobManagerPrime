# ENS/Prime Change Minimization Plan (Selected)

Selected architecture: **Option B with Option A safeguards** (Prime unchanged, keeper-assisted authoritative issuance, explicit script preflight gates).

## Why this is minimal and safe

1. No `AGIJobManagerPrime` runtime edits.
2. No Prime ABI changes.
3. No new Prime storage/events/functions.
4. Keep existing ENSJobPages authority architecture; patch only deployment/cutover risk surface.

## Patch scope

- Add Hardhat helper: `hardhat/scripts/lib/ens-preflight.js`.
- Update `hardhat/scripts/deploy-ens-job-pages.js`:
  - manager compatibility classification,
  - post-deploy Prime↔ENS preflight printout,
  - refuse `LOCK_CONFIG` when keeper-required/unresolved.
- Update `hardhat/scripts/deploy.js`:
  - preflight ENS target before `setEnsJobPages(...)`,
  - fail fast on incompatibility.
- Update Hardhat docs/config comments to reflect keeper-required lean mode and preflight behavior.

## Explicit non-goals

- No Prime redeploy requirement introduced.
- No rewrite of already merged ENS authority subsystems.
