# Discovery Validator Incentives Memo (Prime)

## Problem in previous design
The prior discovery-stage validator flow paid validators immediately on `revealFinalistScore` (bond refund + full `validatorRewardPerReveal`) before winner settlement. That strongly incentivized reveal liveness, but weakly incentivized truthful scoring quality.

## Chosen redesign (practical + auditable)
Prime now uses a two-part validator payout settled during finalist/winner finalization:

1. **Reveal liveness component (minority, 20%)**
   - Revealed validators receive a small fixed liveness share from each revealed reward unit.
   - This keeps reveal incentives intact.

2. **Deferred quality component (majority, 80%)**
   - For finalists meeting `minValidatorReveals`, quality rewards are distributed by deviation band from finalist median score.
   - Closer-to-median scores receive higher weight and more reward share.

3. **Outlier bond downside**
   - Far/outlier revealed scores lose bond value ex post:
     - close (<=5): full bond refund
     - medium (<=15): full bond refund, lower quality weight
     - far (<=30): 50% bond refund
     - extreme (>30): bond fully slashed

4. **Under-quorum rule**
   - If a finalist has fewer than `minValidatorReveals`, revealed validators receive bond refund + liveness component only.
   - No quality pool payout occurs under weak signal; unused quality budget is conservatively refunded to employer via existing budget reconciliation.

## Why this is better under Prime constraints
- **Truth alignment materially improves**: payout is no longer mostly “click reveal.”
- **Auditability is high**: deterministic piecewise bands, bounded loops, no peer-prediction machinery.
- **Mainnet safety**: simple arithmetic, no dynamic/unbounded mechanism additions.
- **Budget safety**: payouts are bounded by pre-funded budgets; unused portions are refunded.

## Residual risks
- Median can still be captured if a cartel controls the reveal majority.
- Parameter tuning remains operationally important (`validatorScoreBond`, `minValidatorReveals`, `validatorRewardPerReveal`).
- Incentive quality still depends on validator identity quality and sybil resistance policy.
