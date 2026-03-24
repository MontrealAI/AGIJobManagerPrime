# PRIME ↔ ENS COMPATIBILITY GAP

Last updated: 2026-03-24

## Current truthful operating mode

- **Authoritative identity:** can be established automatically under the unchanged Prime manager via `handleHook(uint8,uint256)` using lean manager views already exposed on `IAGIJobManagerPrime`.
- **Metadata completeness:** not always automatic, because unchanged Prime does not provide `getJobSpecURI` / `getJobCompletionURI` onchain.
- **Completion text hydration:** may require explicit repair from manager event logs.
- **Settlement safety:** preserved, because ENS writes remain best-effort and non-blocking.

## Gap classification

### Already solved
- Historical identity snapshotting.
- Root isolation across later mutable config changes.
- Mixed-mode compatibility getters for legacy consumers.
- Owner-callable explicit repair/replay surfaces.

### Incomplete before this patch
- Resolver capability detection and auth verification were not production-safe.
- Inspector did not expose resolver-family-safe authorisation truth.
- Operator tooling/docs did not clearly label lean manager mode as keeper-assisted for metadata.
- Mainnet deploy script still allowed ambiguous manager defaults.

### Not required
- Prime runtime changes.
- Typed push-hook migration.
- New Prime storage or public surfaces.

## Production-grade conclusion

A truthful production path is **keeper-assisted / partially automatic without Prime redeploy**:
- automatic authoritative label/name/URI/node issuance where possible;
- explicit metadata completeness state when URIs are unavailable onchain;
- log-driven repair for spec/completion text;
- resolver-family-safe auth observation;
- explicit deploy/runbook cutover checks.
