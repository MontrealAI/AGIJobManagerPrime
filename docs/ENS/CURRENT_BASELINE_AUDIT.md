# Current ENS / Prime Baseline Audit (`main`)

Audit date: 2026-03-24 (UTC)

## Mandatory current-state questions

1. **Does current `main` already auto-issue effective label/name/URI/node for fresh post-cutover jobs under unchanged Prime?**
   - **Yes (identity issuance), partially (metadata).** `ENSJobPages.handleHook(1, jobId)` can fall back to `jobEmployerOf(jobId)` and still establish authority + create/adopt node + resolver/auth writes, even when rich V1 manager views are unavailable. Spec/completion text hydration is keeper-assisted in lean mode.
2. **Does current `main` already solve legacy unmanaged-node adoption?**
   - **Not fully first-class.** Existing replay/repair flows can import exact labels and operate on managed nodes, but unmanaged pre-existing nodes still require explicit operator takeover before replay.
3. **Does current `main` already expose enough root-version state for safe multi-root repair?**
   - **Partially.** Multi-root repair API exists (`repairAuthoritySnapshotExplicit`), but operator observability is still split across events and state reads instead of a single canonical low-friction surface.
4. **Does current `main` already make ENS-side bytecode limits fail-fast in the default deployment path?**
   - **Now yes for gates.** This patch makes `ENSJobPagesInspector` enforced by default in `scripts/check-bytecode-size.js`, and `hardhat/scripts/deploy-ens-job-pages.js` now runs the size gate preflight before deployment.
5. **Which exact remaining changes are still necessary, and why are Prime changes avoidable or unavoidable?**
   - Remaining: legacy adoption ergonomics, richer root-version observability surfacing, and expanded migration scripts/runbook automation.
   - Prime runtime changes remain avoidable; current hook ABI + ENS-side fallback mode is preserved.

## Baseline facts verified

- `AGIJobManagerPrime` still uses low-level `handleHook(uint8,uint256)` best-effort calls.
- `AGIJobManagerPrime` does not implement typed push-hook dispatch.
- `IAGIJobManagerPrimeViewV1` stays unchanged (`ensJobManagerViewInterfaceVersion`, `getJobCore`, `getJobSpecURI`, `getJobCompletionURI`).
- `ENSJobPages` keeps preview/effective separation with authority snapshot semantics and compatibility getters.
- `deploy-ens-job-pages.js` enforces explicit `JOB_MANAGER` on mainnet and root-name/root-node consistency.

## Already merged and correct

- Preview vs effective identity model.
- Conflict-aware authority snapshotting.
- Root-name/namehash consistency check.
- Prime non-blocking settlement semantics for ENS hook failures.
- Inspector manager compatibility truth surface (`none|lean|rich`) and keeper signaling.

## Already merged but incomplete

- Legacy unmanaged-node adoption is still operationally possible but not yet first-class one-call migration.
- Root-version repair exists but is still not surfaced as a single operator-friendly canonical read package.

## Dangerous mismatches identified

- Bytecode headroom on ENS contracts is extremely tight (`ENSJobPages` runtime headroom: 16 bytes), so additive ENSJobPages runtime changes are high-risk.
