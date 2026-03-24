# ENS change minimization plan

## Prime size freeze policy
- Keep `AGIJobManagerPrime` bytecode unchanged.
- Keep manager hook ABI unchanged (`handleHook(uint8,uint256)`).
- Place all new behavior in ENS helper/inspector and tests/docs/scripts.

## Minimal implementation choices
1. Reuse existing replay/create repair entrypoint instead of introducing manager changes.
2. Keep settlement path non-blocking and ENS best-effort failure semantics unchanged.
3. Defer unmanaged-node adoption + root-version info additions until a bytecode-safe refactor path is approved (current ENSJobPages headroom is 16 bytes).

## Rejected alternatives
- New Prime typed hook push ABI: rejected (size/churn risk, unnecessary).
- Broad ENSJobPages redesign: rejected (already-correct architecture preserved).
