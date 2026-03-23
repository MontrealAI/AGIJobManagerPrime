# Current ENS / Prime baseline audit

Date: 2026-03-23
Branch audited: current working branch starting from `main` baseline assumptions.

## Mandatory current-state questions

1. **Is the current ENSJobPages authority model itself already broadly correct?** Yes. The existing design already separates preview vs effective identity, snapshots label/root authority, preserves historical names across later root changes, and enforces `namehash(rootName) == rootNode` on constructor + `setJobsRoot(...)`.
2. **Is the current blocker primarily the Prime↔ENS interface mismatch?** Yes. Prime still emits only `handleHook(uint8,uint256)` and does not implement the richer V1 getter interface, so automatic authority issuance works in lean mode but metadata hydration is only partially automatic.
3. **Does current Prime implement `IAGIJobManagerPrimeViewV1`?** No. `AGIJobManagerPrime` exposes lean getters such as `jobEmployerOf`, `jobAssignedAgentOf`, `getJobSelectionInfo`, and `getJobSelectionRuntimeState`, but not `ensJobManagerViewInterfaceVersion`, `getJobCore`, `getJobSpecURI`, or `getJobCompletionURI`.
4. **Does current Prime call the typed push hooks in `IENSJobPagesHooksV1`?** No. Prime still calls only the generic numeric hook selector for `handleHook(uint8,uint256)`.
5. **Can a truthful keeper-assisted or partially automatic production path be achieved without any Prime runtime change?** Yes.
6. **If yes, what remained to patch?** ENS-side conflict safety, explicit legacy migration under lean-manager mode, removal of unsafe resolver auth guessing, no-label repair hardening, inventory/audit script alignment, and docs/runbook cleanup.
7. **If no, what Prime change is needed?** Not applicable; Prime change was not necessary.

## Already merged and correct

- Preview/effective getters already exist: `previewJobEns*` and `effectiveJobEns*`.
- Compatibility getters are already mixed-mode and must be treated as such.
- Root versioning + authority snapshotting are already present.
- Root consistency checks already enforce `namehash(rootName) == rootNode`.
- Prime hook path remains non-blocking and size-safe because Prime only does a bounded best-effort call to `handleHook(uint8,uint256)`.
- Zero-bytecode-growth lean manager getters already exist in Prime and are sufficient for automatic authority issuance plus partial auth repair.

## Already merged but incomplete

- Lean-mode fallback hooks already existed, but only partially covered metadata completeness.
- Explicit repair entrypoints for texts/auth already existed, but explicit legacy adoption/migration without V1 manager views was missing.
- Inspector already exposed rich status, but its auth observation still guessed a non-canonical `isAuthorised(bytes32,address)` read surface.
- `jobEnsIssued` / `jobEnsReady` were already observed-state checks, but docs still needed to stop describing mixed-mode getters as always-authoritative.

## Still missing before this patch

- Conflict-safe authority establishment for repeated repair/import attempts.
- Safe prohibition on `repairAuthoritySnapshot(jobId, "")` when authority had not yet been established.
- Explicit lean-manager legacy migration/adoption path.
- Script and inspector removal of guessed resolver-auth reads.
- Documentation cleanup for stale `agijob` vs `agijob-`, `syncEnsForJob`, and legacy-only `useEnsJobTokenURI` references.

## Dangerous regressions / mismatches observed pre-patch

- Authority establishment silently no-opped on conflicts instead of proving identity equivalence.
- `repairAuthoritySnapshot(jobId, "")` could proceed whenever a label had previously been snapshotted, which was too permissive for ambiguous legacy recovery.
- Inspector/script auth reads still probed `isAuthorised(bytes32,address)`, which is not the canonical resolver-family read surface to rely on for mainnet status.
- Legacy migration required V1 manager views even though the operational requirement was to support unchanged Prime / explicit owner-supplied recovery.
