# Docs vs Chain Diff

## Chain beats prose

Any mismatch between documentation and a fresh chain-backed audit must be resolved in favor of chain state. This repository now ships dedicated audit and inventory scripts so operators can regenerate the truth set before production actions.

## Proven chain-vs-doc corrections as of 2026-03-23 UTC

- The live prefix hypothesis `agijob-` is confirmed.
- The live root hypothesis `alpha.jobs.agi.eth` is confirmed and matches the configured root node by namehash.
- The live manager/discovery/page address triad supplied by the operator is confirmed.
- The live root is wrapped, and ENSJobPages currently has wrapper-wide approval via `isApprovedForAll`, not via `getApproved`.
- The currently wired public resolver does **not** advertise `setText` or `setAuthorisation` support, so any prose implying automatic full metadata hydration on this exact resolver is stale.
- The currently wired ENSJobPages contract reverts on `validateConfiguration()`, `configurationStatus()`, and `jobAuthorityInfo(uint256)`, so any prose describing the deployed mainnet helper as already authoritative/status-rich is stale.
- The observed Prime deployment currently has `nextJobId = 0`, so any prose implying an existing historical inventory on these exact Prime addresses is stale.

## Known stale-doc risk areas

- Historical docs often describe `agijob<id>.alpha.jobs.agi.eth` as if it were universally authoritative.
- Current live operational assumptions mention the hyphenated prefix `agijob-<id>`.
- Some older prose blurred **preview** values and **effective** values.
- Older runbooks assumed ENS replacement steps but did not require explicit machine-readable inventory or repair classification.

## Corrections made by this patch

- The docs now describe the live-facing name shape as a **preview** format unless a per-job authority snapshot exists.
- The docs explicitly distinguish keeper-assisted authoritative operation from fully automated on-chain operation.
- Runbooks now require chain-backed JSON under `scripts/ens/output/` before cutover, migration, or finalization.

## Current required cutover stance

- Keep `AGIJobManagerPrime` unchanged.
- Deploy the new authoritative `ENSJobPages` implementation from this repository.
- Rewire Prime to the replacement ENSJobPages address.
- Re-run the audit/inventory scripts and do not treat preview values as authoritative until the replacement contract is live.
