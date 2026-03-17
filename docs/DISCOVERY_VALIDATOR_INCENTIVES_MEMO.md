# Discovery Validator Incentives Memo

## Problem statement (old design)

The old discovery-stage validator flow paid full validator compensation as soon as a score was revealed.
That rewarded participation and liveness, but it did **not** make truthful scoring materially better than arbitrary scoring.

In practical terms, validators could optimize for "reveal anything" rather than "reveal an honest estimate," because the largest payout happened before ex post settlement quality was known.

## Option review

### Option A — per-reveal payout only (legacy shape)
- **Mechanics:** full reward on reveal, slash only non-reveal.
- **Pros:** simple, very strong reveal incentive.
- **Cons:** weak truth incentives; little downside for biased reveals; easy to farm by low-effort reveals.
- **Decision:** rejected as insufficiently truth-aligned.

### Option B — small reveal component + deferred quality settlement + outlier penalties
- **Mechanics:**
  - keep score bond posted at commit,
  - on reveal, record score only,
  - settle at finalist finalization using robust reference (median of revealed scores),
  - use deterministic deviation bands for reward weighting and bond refund severity.
- **Pros:** materially improves truth incentives while staying auditable and bounded.
- **Cons:** still vulnerable if cartel controls median majority.
- **Decision:** **chosen** as best practical tradeoff under current Prime constraints.

### Option C — heavy peer-prediction / market-scoring logic
- **Mechanics:** richer scoring games, peer reports, or probabilistic truth-serum style designs.
- **Pros:** potentially stronger theoretical incentive properties.
- **Cons:** higher bytecode/gas, harder auditing, more complexity and UX ambiguity.
- **Decision:** rejected for now as non-minimal and less mainnet-safe.

## Implemented mechanism (current Prime)

### 1) Commit phase
Validator posts `validatorScoreBond` with score commitment.

### 2) Reveal phase
`revealFinalistScore(...)` records revealed score but does **not** grant full payout.

### 3) Final settlement phase
`_settleFinalistValidatorScores(...)` settles each revealed validator deterministically:
- Reference score: median of revealed finalist scores (when quorum is robust).
- Reward pool per finalist: `reveals * validatorRewardPerReveal`.
- Pool split:
  - **10% liveness pool** (`LIVENESS_REWARD_BPS = 1000`),
  - **90% quality pool** (deviation-weighted).
- Deviation bands from median:
  - `<= 5`: full bond refund, highest quality weight,
  - `<= 15`: full bond refund, reduced quality weight,
  - `<= 30`: partial bond refund and reduced liveness+quality share,
  - `> 30`: no bond refund and no reward.

This keeps reveal incentives while making careful scoring materially more profitable than arbitrary reveals.

## Under-quorum policy

If a finalist has fewer reveals than `minValidatorReveals`:
- no quality rewards are paid,
- revealed validators recover bond + only the small liveness component,
- unused quality budget is left unspent and returned through the existing conservative employer refund path at procurement finalization.

This preserves liveness but avoids overpaying weak-signal outcomes.

## Why this is practical and mainnet-safe

- Deterministic, bounded loops over already-capped validator/finalist lists.
- No probabilistic or recursive game-theory machinery.
- No new off-chain trust assumptions.
- Reward spending stays within pre-funded procurement budget; unused budget refunds to employer.
- Non-reveal slashing remains active.

## Residual risks and tuning notes

1. **Median-majority capture:** if colluding validators control most reveals, they can still influence median and payouts.
2. **Parameter sensitivity:** quality depends on practical calibration of `minValidatorReveals`, `validatorScoreBond`, and `validatorRewardPerReveal`.
3. **Signal quality ceiling:** on-chain mechanism cannot verify off-chain trial quality directly; validator quality remains partly social/operational.

