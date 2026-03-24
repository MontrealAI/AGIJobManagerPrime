# ENS Remaining Gaps (Post-Audit)

## Still missing / incomplete

1. **First-class unmanaged-node adoption endpoint**
   - Current state: achievable via manual ownership transfer + replay.
   - Gap: no compact idempotent single-call migration endpoint for wrapped/unwrapped adoption.

2. **Root-version operator observability packaging**
   - Current state: explicit repair entrypoint exists.
   - Gap: operator UX still requires combining multiple reads/log context.

3. **Migration tooling expansion**
   - `scripts/ens/*` already provide strong audit/repair primitives, but adoption-batch orchestration and conflict-code reporting should be expanded further.

4. **Runbook hardening for finalization policy and fuse states**
   - Finalization/fuse statuses are inspectable, but batch cutover playbooks should include stricter pre/post checks and staged canary guidance.

## Explicitly closed in this patch

- ENS-side deployed-contract bytecode gates now fail fast by default for `ENSJobPagesInspector`.
- ENS deploy script now runs size-gate preflight and aborts before broadcast on violations.
