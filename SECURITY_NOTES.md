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
