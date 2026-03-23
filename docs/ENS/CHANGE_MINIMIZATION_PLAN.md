# Change Minimization Plan

## Ranked remediation layers

1. **Docs / scripts / runbooks only**
   - Honest semantics.
   - Chain-backed audit artifacts.
   - Inventory, migration, repair, and cutover procedures.
2. **ENSJobPages-only changes**
   - Immutable authority snapshots.
   - Preview/effective getter split.
   - Status and repair surfaces.
3. **ENSJobPages + helper contracts**
   - Put heavy inspection and aggregation into ENS-side helper contracts.
4. **Minimal Prime ENS-plumbing replacement**
   - Only if ENS-side and keeper/event-driven paths fail to provide truthful authoritative identity.
5. **Prime redeploy**
   - Last resort only.

## Chosen layer

**Layer 2 + 1 + helper inspection tooling.**

Why:
- Prime already emits sufficient events and exposes sufficient getters.
- Settlement already remains non-blocking.
- Authority snapshotting belongs in the ENS layer because identity must remain stable even if root globals later change.
- Scripts and docs are mandatory to make the manager-unchanged path operator-grade.

## Explicit rejections

### Why layer 4 was rejected
Prime bytecode headroom is too small to justify avoidable ENS logic growth, and the required semantics are available without changing the manager runtime.

### Why layer 5 was rejected
A redeploy is not required to obtain authoritative ENS identity semantics. The problem is not settlement correctness; it is ENS authority and operational tooling.
