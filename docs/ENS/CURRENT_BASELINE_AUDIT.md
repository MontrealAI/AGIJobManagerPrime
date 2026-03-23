# CURRENT BASELINE AUDIT

Date: 2026-03-23
Branch audited: current `main` working tree before final patch validation.

## Executive answers

1. **Is the current ENSJobPages authority model itself already broadly correct?** Yes. Preview/effective separation, snapshotted authority, root versioning, and root-namehash enforcement were already present and directionally correct.
2. **Is the current blocker primarily the Prime↔ENS interface mismatch?** Mostly yes. The unchanged Prime manager still uses only `handleHook(uint8,uint256)` and does not expose the rich V1 view surface, so automatic metadata hydration was incomplete even though authority issuance could still succeed.
3. **Does current Prime implement `IAGIJobManagerPrimeViewV1`?** No.
4. **Does current Prime call the typed push hooks in `IENSJobPagesHooksV1`?** No. It still uses the generic numeric hook path.
5. **Can a truthful keeper-assisted or partially automatic production path be achieved without any Prime runtime change?** Yes.
6. **What remained to patch?** Resolver capability/auth detection, inspector auth reads, explicit compatibility signaling, deploy-script honesty, docs/runbooks, and audit/operator artifacts.
7. **Was a Prime change required?** No.

## Already merged and correct

- Preview/effective ENS identity split exists.
- Effective getters read immutable snapshotted authority once established.
- Root versioning exists and preserves historical names across later root changes.
- Constructor and `setJobsRoot(...)` already enforce `namehash(rootName) == rootNode`.
- Compatibility getters remain mixed-mode for old integrations.
- Explicit repair/replay endpoints already exist for manual/keeper paths.
- Prime hook ABI compatibility is already preserved through `handleHook(uint8,uint256)`.
- Prime ENS hook path is already non-blocking and gas-bounded.

## Already merged but incomplete

- Lean-manager fallback could create authoritative nodes automatically, but metadata hydration remained partial when V1 getters were unavailable.
- `jobEnsIssued` / `jobEnsReady` were already observed-chain checks, but docs still needed to stop overclaiming mixed-mode getters as authoritative.
- Scripts already existed for audit/inventory/repair, but auth probing and compatibility labeling still assumed the wrong resolver ABI family.

## Dangerous regressions / mismatches found

- Resolver capability detection treated `0x304e6ade` as an auth ERC-165 interface even though that selector belongs to `setContenthash`, not resolver authorisation support.
- Inspector auth verification guessed `isAuthorised(bytes32,address)` externally, which is not a safe canonical read surface for mainnet resolver families.
- Mainnet ENS deploy script still carried a stale silent `DEFAULT_JOB_MANAGER`, which made ambiguous deployments too easy.
- Docs still needed explicit language that compatibility getters are mixed preview/effective surfaces and that unchanged Prime may need keeper-assisted metadata repair.

## Still missing before patch

- Canonical manager compatibility signaling (`rich` vs `lean`) on the read-heavy inspection path.
- Resolver auth support for both legacy `setAuthorisation` and newer `approve`/`isApprovedFor` families.
- Audit/runbook artifacts reflecting the real unchanged-Prime operating mode.

