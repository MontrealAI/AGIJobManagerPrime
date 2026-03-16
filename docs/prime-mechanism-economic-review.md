# Prime Mechanism & Economic Review Memo

## Scope
This memo reviews the current Prime architecture (`AGIJobManagerPrime` + `AGIJobDiscoveryPrime`) under adversarial behavior assumptions, with explicit focus on discovery scoring, fallback timing, settlement/dispute solvency, and liveness under low participation.

## Mechanism memo (current baseline)
- **Settlement kernel remains conservative:** escrowed payouts, agent/validator/dispute bonds, challenge windows, disputes, owner controls, pause controls, and solvency accounting remain in `AGIJobManagerPrime`.
- **Discovery remains procurement-first:** sealed application commits, reveal gating, bounded-signal shortlist creation, paid finalist trials, commit-reveal finalist scoring, winner handoff, and fallback promotion remain in `AGIJobDiscoveryPrime`.
- **Live-job-sensitive values are frozen:** assignment-time snapshots are used by downstream completion/dispute/finalization paths, protecting already-live jobs from post-assignment parameter drift.
- **ENS remains optional and non-fatal:** settlement is authoritative; ENS hook calls are additive best-effort side effects.

## Economic/game-theory review (12-point adversarial checklist)

1. **Discovery scoring:** score influence is bounded by shortlist and finalist-scoring structure; no direct first-come winner path.
2. **Fallback promotion timing:** fallback exists for designated-winner stalls, but depends on timely keeper/operator execution near boundaries.
3. **Dispute/solvency assumptions:** a single open dispute slot per job plus explicit lock/release accounting limits bond-lock drift.
4. **Commit/reveal withholding:** applicants can still withhold reveal, but commit-time eligibility prevents ineligible slot capture and preserves meaningful competition quality.
5. **Slot griefing:** unauthorized and under-threshold addresses are blocked at commit before consuming scarce applicant slots.
6. **No-show/stall strategies:** bounded windows for accept/trial/scoring reduce indefinite stalls; operations still need active deadline monitoring.
7. **Validator non-reveal strategies:** quorum/tie/low-participation paths escalate to explicit dispute instead of silent auto-success.
8. **Tie behavior:** ties are handled as explicit unresolved states requiring dispute or stale-path intervention, avoiding ambiguous settlement.
9. **Stale selection abuse:** stale-resolution and fallback paths reduce indefinite lock-up, but response latency can still be exploited if unmonitored.
10. **Reward/stake leakage:** explicit lock/unlock transitions and dispute-bond release on resolution/stale paths limit stranded-value risk.
11. **Low-participation corner cases:** low validator participation increases dispute frequency but does not bypass settlement safety checks.
12. **Cross-module interactions (settlement/dispute/expiry/claims/ENS/discovery):** core state transitions remain settlement-led; ENS/public-page failure cannot brick payout/dispute/finalize flows.

## Compact attack-surface table

| Attack surface | Adversary strategy | Current mitigation | Residual risk |
|---|---|---|---|
| Applicant-slot griefing | Unauthorized/low-rep addresses fill `MAX_APPLICANTS` in commit phase | Commit-time `isAuthorizedAgent` + `minReputation` checks before slot consumption | Authorized Sybils still possible if allowlist policy is weak |
| Repeated disputes | Reopen dispute to relock funds / grief finalization | `disputeJob` reverts when `job.disputed == true` | Single open dispute can still delay until moderator/owner stale path |
| Winner stalling | Designated winner misses accept/trial deadlines | Fallback promotion logic + bounded deadlines | Operational lag if no keeper/operator watches deadlines |
| Validator abstention/non-reveal | Validators avoid contentious votes | Quorum/tie logic + dispute escalation + stale dispute owner resolution | Thin participation can increase dispute frequency |
| Tie forcing | Coordinated validators force tie to delay settlement | Tie routes into explicit dispute path instead of accidental finalize | Moderator SLA becomes critical during contention |
| ENS side-effect failure | ENS hook reverts to block core flow | Best-effort hook calls; settlement state remains authoritative | Public-page freshness can lag settlement events |

## Human-review items before mainnet scale-up
1. Run dedicated adversarial simulation on finalist fallback timing under realistic validator/operator latency.
2. Keep strict allowlist/identity controls to reduce authorized-Sybil slot pressure.
3. Maintain moderator SLA + stale-dispute runbook with explicit response windows.
4. Keep bytecode-size headroom tracked on every merge because manager runtime margin is tight.
5. Dry-run and canary-test ENS target contracts before enabling on production traffic.
