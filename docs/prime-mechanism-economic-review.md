# Prime Mechanism & Economic Review Memo

## Scope
This memo reviews the current Prime architecture (`AGIJobManagerPrime` + `AGIJobDiscoveryPrime`) under adversarial behavior assumptions.

## Mechanism memo (current baseline)
- **Settlement kernel remains conservative:** escrowed payouts, agent/validator/dispute bonds, challenge windows, disputes, and owner-operated controls are all preserved in `AGIJobManagerPrime`.
- **Discovery remains procurement-first:** sealed application commits, reveal gating, shortlist from historical score snapshots, trial submissions, commit-reveal finalist scoring, winner handoff, and fallback promotion are preserved in `AGIJobDiscoveryPrime`.
- **Live-job-sensitive values are frozen:** assignment snapshots are used by downstream completion/dispute/finalization paths, protecting already-live jobs from post-assignment parameter drift.
- **ENS remains optional and non-fatal:** settlement is authoritative; ENS hooks are additive best-effort side effects.

## Economic/game-theory review summary

### Discovery scoring & commit/reveal withholding
- Commit-time authorization and reputation checks now force scarce applicant slots to be used by eligible agents only.
- Reveal withholding is still possible by committed agents, but stake penalties and shortlist logic make non-reveal costly and reduce expected gain.

### Fallback timing & no-show/stall strategies
- Designated-winner stalling is bounded by finalist/trial/scoring deadlines and fallback promotion.
- Residual risk remains if multiple finalists coordinate to stall near windows; operators should monitor and actively promote fallback candidates quickly at deadline boundaries.

### Validator behavior, low participation, ties
- Validator non-reveal/abstention risk is mitigated by review windows and dispute paths, but cannot be eliminated in a permissioned set.
- Tie behavior and low-vote outcomes remain explicit protocol states (including dispute escalation), which is safer than silent auto-resolution under thin participation.

### Dispute/solvency assumptions
- Repeated dispute reopening is blocked while a dispute is open, preventing duplicate bond locking against a single dispute slot.
- `lockedDisputeBonds` release paths on moderator resolution and stale-dispute owner resolution keep solvency accounting coherent for tracked disputes.

## Compact attack-surface table

| Attack surface | Adversary strategy | Current mitigation | Residual risk |
|---|---|---|---|
| Applicant-slot griefing | Unauthorized/low-rep addresses fill `MAX_APPLICANTS` in commit phase | Commit-time `isAuthorizedAgent` + `minReputation` checks before slot consumption | Authorized Sybils still possible if operator allowlists weakly |
| Repeated disputes | Reopen dispute to relock funds / grief finalization | `disputeJob` reverts when `job.disputed == true` | Single open dispute can still delay until moderator/owner stale path |
| Winner stalling | Designated winner misses accept/trial deadlines | Fallback promotion logic and bounded deadlines | Operational lag if no keeper/operator watches deadlines |
| Validator abstention | Validators avoid contentious votes | Quorum + dispute escalation + stale dispute owner resolution | Thin participation can increase dispute frequency |
| ENS side-effect failure | ENS hook reverts to block core flow | Best-effort hook calls; settlement state remains authoritative | Public-page freshness can lag settlement events |

## Human-review items before mainnet scale-up
1. Run dedicated adversarial simulation on finalist fallback timing under realistic validator/operator latency.
2. Keep strict allowlist/identity controls to reduce authorized-Sybil slot pressure.
3. Maintain moderator SLA + stale-dispute runbook with explicit response windows.
4. Keep bytecode-size headroom tracked on every merge because manager runtime margin is tight.
