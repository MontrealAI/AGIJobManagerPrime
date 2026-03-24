# Current ENS/Prime Baseline Audit (main branch)

Audit date: 2026-03-24 (UTC).

## Mandatory current-state questions

1. **Is the current ENSJobPages authority model broadly correct?** Yes. Preview/effective split, authority snapshotting, root versioning, and conflict-aware authority establishment are present.
2. **Is the current blocker instead Prime↔ENS interface mismatch?** Yes. Prime remains lean (`handleHook(uint8,uint256)` + limited getters), so automatic spec/completion hydration is partial without keeper replay.
3. **Does current Prime implement `IAGIJobManagerPrimeViewV1`?** No.
4. **Does current Prime call typed push hooks in `IENSJobPagesHooksV1`?** No; it calls legacy `handleHook(uint8,uint256)` only.
5. **Can a truthful keeper-assisted production path be achieved without Prime runtime change?** Yes.
6. **What remains to patch?** Hardhat preflight/cutover safeguards, explicit compatibility classification in deploy tooling, lock refusal in unsafe compatibility mode, and audit/runbook refresh.
7. **If Prime changed, what bytecode cost?** Not applicable; Prime unchanged in this patch.

## Already merged and correct

- `ENSJobPages` enforces preview vs effective identity separation and preserves compatibility getters as preview-or-effective wrappers.
- Authority snapshots pin label/root/node; post-snapshot mutable globals do not retroactively rewrite effective identity.
- `setJobsRoot(...)` enforces `namehash(rootName) == rootNode` and registers root versions.
- `repairAuthoritySnapshot(...)` no longer permits silently crystallizing a preview label for unsnapshotted legacy jobs.
- `_establishAuthorityForRootVersion(...)` is conflict-aware and reverts on mismatched re-establishment.
- Chain-observed status semantics for `jobEnsIssued` / `jobEnsReady` are already non-sticky and resolver/text aware.
- Inspector already reads ENS owner/resolver/text/auth observations and classifies manager compatibility (`none|lean|rich`).

## Already merged but incomplete

- Deployment scripts validated address shape/code, but Prime↔ENS semantic preflight remained too weak.
- ENS deploy script allowed `LOCK_CONFIG` in keeper-required mode, which is operationally unsafe for cutover/repair windows.
- Prime deploy script could wire `setEnsJobPages(...)` without proving runtime hook compatibility and manager-target alignment.

## Still missing before this patch

- Script-level machine-readable preflight object for manager mode + hook callability + target jobManager alignment.
- Explicit refusal path for unsafe `LOCK_CONFIG` requests.
- Canonical Hardhat operator docs fully aligned to new preflight gates.

## Dangerous regressions checked and rejected

- No evidence of retroactive effective identity drift in current authority model.
- No evidence of settlement-blocking ENS paths; Prime still performs best-effort bounded hook calls.
- Main residual risk was cutover miswiring, now addressed in deploy scripts.
