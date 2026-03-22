# Docs vs Chain Diff

## Current delta status
- **Blocked by environment networking:** this sandbox could not complete Ethereum mainnet RPC reads on 2026-03-22 UTC.
- **Result:** repo docs were updated to explicitly label the supplied live addresses/root/prefix as hypotheses until `scripts/ens/audit-mainnet.ts` succeeds from an operator-connected environment.

## Repo corrections made in this patch
- Preview terminology is now explicitly separated from authoritative/effective terminology in the ENS contract surface.
- The ENS docs now instruct operators to prefer chain-backed JSON artifacts over stale prose.
- The historical default example has been aligned around the current preview prefix format `agijob-<jobId>`.
