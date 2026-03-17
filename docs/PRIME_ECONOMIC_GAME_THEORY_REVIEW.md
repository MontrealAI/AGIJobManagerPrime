# Prime Economic / Game-Theory Review Memo

## Scope
Review covers Prime procurement (`AGIJobDiscoveryPrime`) and settlement (`AGIJobManagerPrime`) with emphasis on winner selection, fallback timing, dispute/solvency, and ENS side effects.

## Attack-surface table

| Surface | Adversarial strategy | Mitigation in code | Residual risk |
|---|---|---|---|
| Application-slot griefing / reveal withholding | Spam commits from unauthorized or underqualified identities, then do not reveal | Commit-time authorization + reputation checks now gate admission (`commitApplication`), and unrevealed commits are penalized in `discoveryStats`. | Sybil identities that can pass auth still require governance/identity controls off-chain. |
| Finalist stall/no-show | Finalist accepts shortlist but does not submit trial | Stake forfeiture to employer and default counters in `finalizeWinner`. | Requires adequate finalist stake configuration. |
| Validator non-reveal / low-effort reveal | Commit score then withhold reveal, or reveal arbitrary values for guaranteed payout | Unrevealed bonds are slashed, and revealed payout is deferred to finalization with liveness+quality split and deviation-band bond penalties (`_settleFinalistValidatorScores`). | Median-majority capture remains possible if validator cartel controls reveals. |
| Cartelized validator outlier scoring | Extreme score manipulation | Median scoring reduces outlier influence; minimum reveal threshold required. | If cartel controls majority of reveals, median still captured. |
| Stale winner option abuse | Designated winner waits indefinitely | `selectionExpiresAt` plus permissionless `promoteFallbackFinalist`. | If no fallback satisfies min reveals, procurement closes without winner. |
| Orphaned procurement capital | Proc is abandoned before winner finalization and funds remain parked in discovery | New explicit `cancelProcurement` unwind path (employer/owner only pre-winner-finalization) returns application/finalist stakes, validator score bonds, and stipend/reward budget to claimable balances. | Governance/operator misuse of early cancellation remains a policy risk and should be monitored. |
| Discovery budget leakage | Over-locking stipend/reward budget | Explicit budget quote + post-finalization budget refund to employer (`claimable`). | Employer must claim; funds are pull-based. |
| Settlement insolvency drift | Locked balances not tracked through edge outcomes | Strict `lockedEscrow/locked*Bonds` accounting and `withdrawableAGI` solvency check. | External ERC20 anomalies (fee-on-transfer/reverting tokens) remain an operator risk. |
| ENS integration bricking settlement | ENS/job-page target reverts | ENS hooks are best-effort and bounded; failures are ignored so settlement state remains authoritative. | Public page consistency can lag settlement truth. |

## Changes implemented from this review

1. Reintroduced optional ENSJobPages wiring on Prime manager (`setEnsJobPages`) and bounded best-effort lifecycle hooks (create/assign/completion/revoke/lock).
2. Ensured terminal settlement paths invoke revoke/lock hooks while keeping settlement authoritative and non-fatal.
3. Added discovery autonomy/readability helpers:
   - `claimable(address)`
   - `isFallbackPromotable(procurementId)`
   - `nextActionForProcurement(procurementId)` + phase helpers
4. Added a permissionless `advanceProcurement` entrypoint to reduce operator liveness risk by allowing any keeper to finalize shortlist/winner stages and promote fallback after timeout.
5. Added tests covering ENS best-effort semantics, fallback promotability status, and staged keeper progression through `advanceProcurement`.

6. Hardened procurement admission and fairness:
   - `commitApplication` now enforces agent authorization + minimum reputation at commit time (not only reveal time), reducing low-cost slot capture DOS.
   - shortlist ordering now uses deterministic tie-break (`address` ascending) when historical scores are equal, reducing reveal-order/manipulation bias.
7. Added explicit orphan-recovery operation:
   - `cancelProcurement(procurementId)` allows employer/owner cancellation before winner finalization and safely unwinds parked capital into pull-based `claimable` balances.
8. Added tests for commit-time admission gating and orphan cancellation unwind behavior.

## Residual risks requiring human pre-mainnet review

1. Parameter governance quality: stake sizes, min reveals, and timing windows must be tuned per market/liquidity conditions.
2. Validator identity quality: anti-sybil identity and validator independence remain partially social/off-chain.
3. Employer strategy attacks: employers can still set low budgets/thresholds that reduce procurement quality without violating contract rules.
4. Off-chain evidence quality: trial URI and deliverable quality cannot be fully verified on-chain.


## Discovery validator incentive hardening (latest)

Detailed discovery-validator incentive rationale and option comparison are documented in `docs/DISCOVERY_VALIDATOR_INCENTIVES_MEMO.md`.

- Validator payout is no longer fully credited at `revealFinalistScore`; settlement occurs in winner finalization.
- Reward shape is now: small liveness share (10%) + majority quality share (90%, median-deviation weighted), with stronger far-outlier bond/liveness penalties.
- Extreme outliers now lose bond value ex post instead of always receiving full bond refund.
- Under-quorum finalists do not pay quality rewards; unused budget is refunded in existing conservative employer refund logic.
