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

3. **Inspector read-surface extension (read-only)**
   - Added compact recommendation code and root-version read probes via safe staticcalls.
   - No manager ABI changes.

## Deferred (separate patch due ENSJobPages 16-byte runtime headroom)

- First-class unmanaged-node adoption API directly inside `ENSJobPages`.
- Additional ENSJobPages public root-version getters.

These are deferred to avoid breaching EIP-170 under current headroom constraints; any future attempt should use either:
- helper contract offloading, or
- carefully budgeted ENSJobPages refactor with compensating size reductions.
