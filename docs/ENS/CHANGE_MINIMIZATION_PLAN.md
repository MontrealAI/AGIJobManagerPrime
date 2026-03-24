# ENS Change-Minimization Plan

## Objectives

- Preserve current merged ENS authority architecture.
- Preserve zero-Prime-runtime-change default.
- Tighten production safety with minimal bytecode impact.

## Decisions in this patch

1. **Prime unchanged**
   - Keep `handleHook(uint8,uint256)` path.
   - Keep current best-effort/non-blocking ENS behavior.

2. **Bytecode gate hardening (scripts-only)**
   - Enforce `ENSJobPagesInspector` size gate by default.
   - Run `scripts/check-bytecode-size.js` preflight in `deploy-ens-job-pages.js` before deployment.

3. **Migration/adoption moved to dedicated ENS-side helper**
   - Added `ENSJobPagesMigrationHelper` so legacy wrapped/unwrapped unmanaged nodes are adoptable without touching Prime runtime.
   - Helper requires temporary `ENSJobPages` ownership during migration execution, then ownership can be returned to operator multisig.

4. **Deploy preflight tightened (scripts-only)**
   - `deploy-ens-job-pages.js` now enforces ENS artifact budget checks (limit + configurable minimum headroom) after `check-bytecode-size.js`.

## Kept intentionally out-of-scope

- Prime runtime modifications.
- Automatic manager-side finalization/fuse burn paths.
- `ENSJobPages` runtime growth (headroom remains critically tight at 16 bytes).
