# Observed Mainnet State

_As of 2026-03-22 UTC, direct RPC reads from this execution environment failed with `ENETUNREACH`, so this document explicitly separates proven local facts from chain hypotheses pending replay from a networked operator workstation._

## Proven locally
- The repo's active ENS integration path is `AGIJobManagerPrime -> handleHook(uint8,uint256) -> ENSJobPages`, and the current ENS-side implementation only requires the Prime view surface `getJobCore`, `getJobSpecURI`, and `getJobCompletionURI`. This is proven from source, not chain reads.
- The contract code defaults the live preview prefix to `agijob-` and treats `alpha.jobs.agi.eth` as a valid root format.

## Chain hypotheses to verify with `scripts/ens/audit-mainnet.ts`
- ENSJobPages: `0x97E03F7BFAC116E558A25C8f09aEf09108a2779d`
- AGIJobManagerPrime: `0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e`
- AGIJobDiscoveryPrime: `0xd5ef1dde7ac60488f697ff2a7967a52172a78f29`
- intended jobs root name: `alpha.jobs.agi.eth`
- expected current active prefix: `agijob-`

## Operational note
Chain state wins over docs. Re-run the audit script from a networked machine before cutover and treat the generated JSON in `scripts/ens/output/` as the authoritative record.
