# Prime autonomy + economic/game-theory review memo

## Scope

Reviewed:
- `AGIJobManagerPrime` settlement-liveness surfaces.
- `AGIJobDiscoveryPrime` procurement scoring, finalist progression, fallback promotion, and claims.
- Integration assumptions through `IAGIJobManagerPrime`.

## Implemented hardening changes

1. **Deterministic autonomy read surfaces for settlement jobs**
   - Added `isFinalizable(jobId)`.
   - Added `isExpirable(jobId)`.
   - Added `isCheckpointFailed(jobId)`.
   - Added `nextActionForJob(jobId)` enum surface.
   - Added `getAutonomyStatus(jobId)` aggregated view.

2. **Deterministic autonomy read surfaces for procurements**
   - Added `isFallbackPromotable(procurementId)`.
   - Added `nextActionForProcurement(procurementId)` enum surface.
   - Added `getAutonomyStatus(procurementId)` for procurement progression.

3. **Fallback tie-break robustness**
   - `promoteFallbackFinalist` now resolves equal composite scores deterministically by lower-address tiebreak.
   - Prevents ambiguous offchain bot behavior and racey subjective fallback selection.

## Attack-surface table

| Surface | Risk | Mitigation now in code | Residual risk |
|---|---|---|---|
| Winner stalling | Designated winner can fail to accept and block job | `promoteFallbackFinalist` + explicit `isFallbackPromotable`/`nextActionForProcurement` keeper signaling | Requires external keeper/operator to call promotion |
| Checkpoint no-show | Assigned agent can stall pre-completion | `isCheckpointFailed` + `nextActionForJob` make checkpoint-fail action machine-readable | Still requires third party to execute `failCheckpoint` |
| Post-review liveness ambiguity | Users unsure when finalize/expire is valid | `isFinalizable`/`isExpirable` + aggregate status | Offchain UIs must consume and render these fields |
| Fallback tie ambiguity | Equal composite finalists can produce unclear bot policy | Deterministic address-based tiebreak in fallback promotion | Determinism is not fairness-optimal; simple and auditable but coarse |
| Validator non-reveal | Score commits can be withheld | Existing `_slashNonRevealValidatorBonds` retained; unreturned bonds credited to employer | Economic parameters still need governance tuning by market |

## Mechanism memo (compact)

- Premium path remains procurement-first: commit/reveal applications, shortlist, paid trials, validator score commit/reveal, winner designation, fallback promotion.
- Historical score remains bounded and damped; winner remains trial-score dominated via configurable trial/historical weights.
- Discovery default behaviors (unrevealed app, finalist no-accept, finalist no-trial) remain explicitly penalized through discovery stats.
- Settlement remains conservative and authoritative; discovery only designates selected agent.

## Residual risks requiring human pre-mainnet review

1. **Parameter governance risk**: badly tuned `minValidatorReveals`, `validatorScoreBond`, `validatorRewardPerReveal`, and acceptance windows can still create weak equilibria.
2. **Keeper dependence**: permissionless transitions still require active agents/keepers to execute calls.
3. **Large kernel runtime size**: current manager runtime exceeds EIP-170 and needs additional refactor/size reduction before Ethereum mainnet deployment.
4. **Cartel behavior**: commit/reveal + bonding helps, but collusion in small validator pools remains a socio-economic, not purely technical, risk.

