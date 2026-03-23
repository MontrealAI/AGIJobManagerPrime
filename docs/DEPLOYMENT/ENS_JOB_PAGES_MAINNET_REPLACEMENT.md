# ENSJobPages Mainnet Replacement Runbook

This runbook covers replacing the ENS helper behind `AGIJobManagerPrime` without redeploying Prime.

## Canonical live assumptions to verify before cutover

- Prime manager target: `0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e`
- Observed ENS helper target: `0x97E03F7BFAC116E558A25C8f09aEf09108a2779d`
- Intended root: `alpha.jobs.agi.eth`
- Intended prefix: `agijob-`

Do not trust prose alone; re-run the audit scripts first.

## Phase 0

Run the chain-backed audits before any deploy or rewire step:

```bash
node scripts/ens/audit-mainnet.ts
node scripts/ens/phase0-mainnet-snapshot.mjs
node scripts/ens/inventory-job-pages.ts
```

Required outputs:

- `scripts/ens/output/audit-mainnet.json`
- `scripts/ens/output/inventory-job-pages.json`
- `docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-current.json`
- `docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-current.md`

## Deploy replacement ENSJobPages

```bash
cd hardhat
npm run compile
DRY_RUN=1 DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT npm run deploy:ens-job-pages:mainnet
DEPLOY_CONFIRM_MAINNET=I_UNDERSTAND_MAINNET_DEPLOYMENT VERIFY=1 JOB_MANAGER=0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e npm run deploy:ens-job-pages:mainnet
```

The deploy script now defaults `JOB_MANAGER` to the current Prime manager address and refuses root-name / namehash mismatches.

## Manual post-deploy steps

1. Wrapped-root owner grants NameWrapper approval to the new ENS helper.
2. Re-run `validateConfiguration()` and proceed only when the bitmask is `0`.
3. Prime owner calls `setEnsJobPages(newEnsJobPages)`.
4. Run the audit + inventory scripts again and compare outputs.
5. Only then consider `lockConfiguration()`.

## Repair model after cutover

Do **not** use stale manager-only flows such as `syncEnsForJob(...)`.

Use explicit ENS-side repair entrypoints instead:

- `repairAuthoritySnapshotExplicit(...)`
- `repairResolver(...)`
- `repairTextsExplicit(...)`
- `repairAuthorisationsExplicit(...)`
- `replayCreateExplicit(...)`
- `replayAssignExplicit(...)`
- `replayCompletionExplicit(...)`
- `replayRevokeExplicit(...)`
- `replayLockExplicit(...)`

Generate exact calldata/plan files with:

```bash
node scripts/ens/repair-from-logs.ts
JOB_ID=<id> EXACT_LABEL=<label> node scripts/ens/repair-job-page.ts
```

## Canary sequence

1. Create one fresh job and confirm automatic authority issuance.
2. Run one explicit repair-from-logs flow.
3. Run one legacy exact-label adoption or authority repair.
4. Run one wrapped finalization flow.
5. Confirm a deliberate ENS-side failure does not block Prime settlement.

## Rollback

If the replacement needs to be reverted:

1. Prime owner calls `setEnsJobPages(previousEnsJobPages)`.
2. Keep historical labels untouched.
3. Use explicit repair/replay functions against the surviving helper to reconcile any partially written jobs.
