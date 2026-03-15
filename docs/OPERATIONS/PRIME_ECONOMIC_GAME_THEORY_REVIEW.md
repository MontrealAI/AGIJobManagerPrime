# Prime Economic / Game-Theory Review Memo

This memo captures a pre-mainnet adversarial review for Prime procurement + settlement.

## Scope
- `contracts/AGIJobManagerPrime.sol`
- `contracts/AGIJobDiscoveryPrime.sol`
- `contracts/interfaces/IAGIJobManagerPrime.sol`

## Attack surface table

| Surface | Threat | Existing/added mitigations | Residual risk |
|---|---|---|---|
| Commit/reveal applications | Reveal withholding to grief shortlist | Unrevealed application stake remains slashable to employer path through shortlist finalization; defaults tracked in `discoveryStats` with decaying penalty. | Sybil applicants can still spam with enough capital. |
| Shortlist manipulation | Incumbent lock-in via pure historical score | Bounded historical score with explicit trial-weight dominance (`historicalWeightBps + trialWeightBps = 10000` and trial median scoring). | Long-run cartel behavior still needs off-chain monitoring. |
| Finalist stalling | Selected finalists accept then do not submit trials | Locked finalist stake forfeiture + default penalty paths; winner requires minimum reveal count. | Employer can still experience delay cost until deadlines elapse. |
| Validator scoring | Commit but do not reveal to censor score set | Non-reveal validator bond slashing in discovery finalization. | If validator set is too small, liveness degrades. |
| Winner handoff | Stale designated winner blocks settlement | Selection timeout (`selectionExpiresAt`) + permissionless `promoteFallbackFinalist`. | Poor parameterization of acceptance windows can still increase latency. |
| Settlement finalization | Ambiguity for keepers and UIs causes liveness misses | Added explicit autonomy helper views in settlement: `isFinalizable`, `isExpirable`, `isCheckpointFailed`, `nextActionForJob`. | Keeper implementation quality remains an operator responsibility. |
| Solvency accounting | Locked-fund leakage across dispute/expiry/finalization | Pull-based claim accounting and explicit locked bond buckets retained; no new externalized settlement side effects were introduced. | Full formal verification still recommended for mainnet TVL growth. |

## Code-level hardening done in this upgrade

1. Added settlement autonomy helper views to support deterministic keeper/UI action routing:
   - `isFinalizable(jobId)`
   - `isExpirable(jobId)`
   - `isCheckpointFailed(jobId)`
   - `nextActionForJob(jobId)`
2. Exposed those methods in `IAGIJobManagerPrime` for discovery/periphery/operator interoperability.

## Residual risks requiring human review

1. Parameter regime risk: misconfigured windows/bonds can still cause slow procurement convergence.
2. Validator cartel risk: permissioned/low-diversity validator sets can collude on trial scoring.
3. Economic stress risk: extreme token volatility can distort bond deterrence in real terms.
4. Operational risk: no on-chain mechanism can force quality, only incentive-compatible behavior under configured constraints.
