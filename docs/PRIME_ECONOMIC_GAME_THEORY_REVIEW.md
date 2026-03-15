# Prime Economic / Game-Theory Review Memo

## Scope
Reviewed Prime-critical adversarial surfaces in:
- `AGIJobManagerPrime` settlement liveness/solvency transitions.
- `AGIJobDiscoveryPrime` premium procurement scoring, fallback, and validator behavior.
- ENS side-effect integration posture for Prime settlement lifecycle.

## Attack-surface table

| Surface | Risk | Mitigation implemented | Residual risk |
|---|---|---|---|
| ENS hooks on create/assign/complete/revoke/lock | External revert could brick settlement | Prime now uses bounded low-level best-effort hook calls with success event logging only (`EnsHookAttempted`) | ENS metadata inconsistency remains possible; settlement remains authoritative |
| Winner stall after discovery designation | Liveness degradation if designated finalist does not accept | Existing fallback promotion path retained; helper status views added for discoverability | Keeper participation still required for rapid progression |
| Opaque progression / operator uncertainty | Missed windows and delayed progression under adversarial timing | Added `isFinalizable`, `isExpirable`, `isCheckpointFailed`, `nextActionForJob`, `nextActionForProcurement`, `canClaim`, `isFallbackPromotable` views | Off-chain bots still need robust infra and monitoring |
| Validator reveal withholding in discovery | Distorted score set and budget griefing | Existing non-reveal score-bond slashing retained and documented | Cartel behavior may still influence medians under low validator participation |
| Tie / low-vote settlement corners | Stalemate, forced disputes, delayed settlement | Existing quorum + tie-to-dispute conservative behavior retained | Governance tuning required per market conditions |

## Explicit changes made
1. Reintroduced optional ENSJobPages support directly in Prime settlement.
2. Ensured ENS side effects are strictly non-fatal, bounded, and observable.
3. Added autonomy/readability helper views for job/procurement progression and claims.

## Remaining risks requiring human review
- Parameter tuning for validator quorum/thresholds and discovery deadlines under real liquidity conditions.
- Adversarial cartel simulations at scale (beyond current deterministic unit/integration tests).
- Production monitoring design for keeper redundancy and missed-deadline alerting.
- Final pre-mainnet audit focusing on economic griefing and gas-based DoS under high participant counts.
