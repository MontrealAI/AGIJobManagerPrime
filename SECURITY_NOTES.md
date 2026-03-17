# Security Notes

## Prime hardening notes (current)

- **Owner control retained**: `AGIJobManagerPrime.renounceOwnership()` now always reverts with `RenounceOwnershipDisabled` to prevent accidental loss of operator control.
- **Repeated dispute-bond protection**: `disputeJob` now reverts with `DisputeAlreadyOpen` when a dispute is already live, preventing duplicate dispute-bond locking and repeated-open ambiguity.
- **Live-job rule freezing**: assignment now snapshots:
  - `completionReviewPeriod`
  - `disputeReviewPeriod`
  - `challengePeriodAfterApproval`

  Finalization and stale-dispute resolution use per-job snapshots, preventing owner parameter updates from retroactively changing dispute/settlement timing rules for already-live jobs.
- **Deployability guardrails**: repository size checks now enforce both runtime bytecode and initcode ceilings with printed headroom for Prime contracts.

## Remaining pre-mainnet process requirements

- Run static analysis (Slither) in CI/ops environment where `slither-analyzer` is installed.
- Run independent human review of procurement economics, dispute assumptions, and operational runbooks before high-value mainnet usage.

## Discovery Validator Incentives Note (Prime)

- **Old issue**: discovery-stage validator economics were too reveal/liveness-heavy. Validators could often do reasonably well by revealing any score, with weak ex post differentiation between honest/close scores and noisy/outlier scores.
- **New mechanism**:
  - `revealFinalistScore` records score only (no immediate reward/bond payout).
  - settlement occurs in `_finalizeWinner` via `_settleFinalistValidatorScores`.
  - for finalists meeting `minValidatorReveals`, payout uses median-reference deviation bands:
    - `d <= 5`: 100% bond refund, full quality weight.
    - `5 < d <= 10`: 100% bond refund, reduced quality weight.
    - `10 < d <= 20`: 80% bond refund, low quality weight.
    - `d > 20`: 50% bond refund, zero quality weight.
  - non-reveal validators are still slashed.
  - under quorum (`reveals < minValidatorReveals`): revealers recover bond only; no reward payout.
  - any slashed bond and unused validator reward budget is returned to employer.
- **Why better**: reward is now predominantly quality-based and deferred to ex post settlement, with deterministic outlier penalties (including banded liveness reduction to zero for extreme outliers) and conservative budget accounting.
- **Residual risk**: median-based mechanisms are still vulnerable to coordinated majority manipulation/collusion among revealers. This hardening materially improves incentives but does not eliminate cartel risk under adversarial-majority participation.
- **Business-tunable parameters**: operators should tune `LIVENESS_REWARD_BPS`, deviation band thresholds (`<=5/<=10/<=20/>20`), and `validatorScoreBond` vs `validatorRewardPerReveal` so extreme-outlier strategies remain economically unattractive.
