# Docs vs Chain Diff

## Chain beats prose

Any mismatch between documentation and a fresh chain-backed audit must be resolved in favor of chain state. This repository now ships dedicated audit and inventory scripts so operators can regenerate the truth set before production actions.

## Known stale-doc risk areas

- Historical docs often describe `agijob<id>.alpha.jobs.agi.eth` as if it were universally authoritative.
- Current live operational assumptions mention the hyphenated prefix `agijob-<id>`.
- Some older prose blurred **preview** values and **effective** values.
- Older runbooks assumed ENS replacement steps but did not require explicit machine-readable inventory or repair classification.

## Corrections made by this patch

- The docs now describe the live-facing name shape as a **preview** format unless a per-job authority snapshot exists.
- The docs explicitly distinguish keeper-assisted authoritative operation from fully automated on-chain operation.
- Runbooks now require chain-backed JSON under `scripts/ens/output/` before cutover, migration, or finalization.

## Still requires explicit chain confirmation

Because this sandbox could not read mainnet directly, the exact current values for owner, resolver, approvals, `configLocked`, and historical inventory are not asserted here as proven facts. They must come from the generated audit artifacts.
