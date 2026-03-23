# ENS change minimization plan

## Chosen architecture

1. **Do not change `AGIJobManagerPrime`.**
2. **Patch `ENSJobPages` in place** for conflict safety and explicit lean-manager migration capability.
3. **Use `ENSJobPagesInspector` as canonical rich status** instead of bloating Prime or overloading compatibility getters.
4. **Use scripts + logs for metadata recovery** instead of adding Prime getters.
5. **Update docs/runbooks** so operators never call preview values authoritative and never rely on nonexistent repair helpers.

## Minimal patch list

- Harden authority establishment to reject conflicting re-snapshots.
- Disallow no-label authority repair before authority already exists.
- Add explicit `migrateLegacyWrappedJobPageExplicit(...)` for unchanged-Prime / owner-supplied migration.
- Remove guessed `isAuthorised(bytes32,address)` auth reads from inspector + inventory script + capability probing.
- Keep `handleHook(uint8,uint256)` numeric ABI unchanged.
- Keep Prime runtime unchanged.
- Refresh deployment/runbook docs and retain log-driven repair scripts as canonical metadata recovery path.

## Explicit non-goals

- No new Prime storage.
- No new Prime events.
- No typed-hook dependency for current production readiness.
- No semantic rewrite of the existing authority snapshot architecture.
