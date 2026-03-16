# Prime Economic / Game-Theory Review Memo

## Scope
Review covers Prime procurement (`AGIJobDiscoveryPrime`) and settlement (`AGIJobManagerPrime`) with emphasis on winner selection, fallback timing, dispute/solvency, and ENS side effects.

## Attack-surface table

| Surface | Adversarial strategy | Mitigation in code | Residual risk |
|---|---|---|---|
| Application reveal withholding | Commit but do not reveal to crowd out others | Unrevealed applications receive default penalty via `discoveryStats` and lose reveal opportunity. | Sybil identities can still absorb penalties off-protocol. |
| Finalist stall/no-show | Finalist accepts shortlist but does not submit trial | Stake forfeiture to employer and default counters in `finalizeWinner`. | Requires adequate finalist stake configuration. |
| Validator non-reveal | Commit score then withhold reveal to sabotage median | Unrevealed validator score bonds are slashed to employer in `_slashNonRevealValidatorBonds`. | Small bond settings weaken deterrence. |
| Cartelized validator outlier scoring | Extreme score manipulation | Median scoring reduces outlier influence; minimum reveal threshold required. | If cartel controls majority of reveals, median still captured. |
| Stale winner option abuse | Designated winner waits indefinitely | `selectionExpiresAt` plus permissionless `promoteFallbackFinalist`. | If no fallback satisfies min reveals, procurement closes without winner. |
| Discovery budget leakage | Over-locking stipend/reward budget | Explicit budget quote + post-finalization budget refund to employer (`claimable`). | Employer must claim; funds are pull-based. |
| Settlement insolvency drift | Locked balances not tracked through edge outcomes | Strict `lockedEscrow/locked*Bonds` accounting and `withdrawableAGI` solvency check. | External ERC20 anomalies (fee-on-transfer/reverting tokens) remain an operator risk. |
| ENS integration bricking settlement | ENS/job-page target reverts | ENS hooks are best-effort and bounded; failures are ignored so settlement state remains authoritative. | Public page consistency can lag settlement truth. |

## Changes implemented from this review

1. Reintroduced optional ENSJobPages wiring on Prime manager (`setEnsJobPages`) and bounded best-effort lifecycle hooks (create/assign/completion/revoke/lock).
2. Ensured terminal settlement paths invoke revoke/lock hooks while keeping settlement authoritative and non-fatal.
3. Added discovery autonomy/readability helpers:
   - `canClaim(address)`
   - `isFallbackPromotable(procurementId)`
   - `nextActionForProcurement(procurementId)`
   - `getAutonomyStatus(procurementId)`
4. Added a permissionless `advanceProcurement` entrypoint to reduce operator liveness risk by allowing any keeper to finalize shortlist/winner stages and promote fallback after timeout.
5. Added tests covering ENS best-effort semantics, fallback promotability status, and staged keeper progression through `advanceProcurement`.

## Residual risks requiring human pre-mainnet review

1. Parameter governance quality: stake sizes, min reveals, and timing windows must be tuned per market/liquidity conditions.
2. Validator identity quality: anti-sybil identity and validator independence remain partially social/off-chain.
3. Employer strategy attacks: employers can still set low budgets/thresholds that reduce procurement quality without violating contract rules.
4. Off-chain evidence quality: trial URI and deliverable quality cannot be fully verified on-chain.
