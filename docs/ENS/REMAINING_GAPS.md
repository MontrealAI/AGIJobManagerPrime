# Remaining ENS cutover gaps

## Confirmed still-open code gaps
- First-class unmanaged-node adoption/migration flow in `ENSJobPages` (wrapped and unwrapped parent-controlled takeover) remains open.
- Direct per-version root metadata reader (`rootVersionInfo`) remains open.

## Operational follow-ups
- Refresh memo/doc bytecode tables from fresh CI size output.
- Run mainnet dry-run scripts and persist JSON snapshots in `scripts/ens/output/` before cutover.
- Execute canary post-cutover and archive proofs.
