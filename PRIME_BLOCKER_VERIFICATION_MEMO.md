# Prime Mainnet Blocker Verification Memo (Current `main` Baseline)

This memo records the blocker-by-blocker verification pass performed on the current branch baseline before any architectural changes.

## Verification outcome summary

| Blocker | Status on current baseline | Evidence |
|---|---|---|
| Canonical Hardhat deploy path inconsistent or legacy-targeted | **Already resolved** | `hardhat/scripts/deploy.js` deploys `AGIJobManagerPrime` then `AGIJobDiscoveryPrime`, wires `setDiscoveryModule`, captures `completionNFT`, optional ENS wiring, optional ownership transfer, optional verification. |
| Repeated dispute openings possible | **Already resolved** | `DisputeAlreadyOpen` custom error exists and `disputeJob()` reverts when `job.disputed` is already true. |
| Applicant-slot griefing at commit | **Already resolved** | `AGIJobDiscoveryPrime.commitApplication()` checks `isAuthorizedAgent(...)` and `reputation(msg.sender) >= p.minReputation` before applicant-slot consumption. |
| Live-job-sensitive mutable globals | **Already resolved** | Assignment-time snapshots are stored in job state (`completionReviewPeriodSnapshot`, `disputeReviewPeriodSnapshot`, `challengePeriodAfterApprovalSnapshot`, `voteQuorumSnapshot`, validator thresholds, slash bps), and downstream paths consume snapshots. |
| Ownership hardening (`renounceOwnership`) incomplete | **Already resolved** | Both Prime contracts override `renounceOwnership()` to revert via custom errors. |
| Security verification artifact stale/legacy scoped | **Needs refresh** | Existing report is Prime-scoped but contained stale “fixed by” wording from earlier iterations; refreshed for current-baseline verification framing. |
| Size gate runtime-only (no initcode) | **Already resolved** | `scripts/check-bytecode-size.js` enforces runtime and initcode limits, printing per-contract sizes and headroom. |

## Notes

- No Prime-architecture redesign was required.
- ENS side effects remain optional and best-effort in the canonical flow.
- Completion NFT capture remains part of canonical deployment output.

## Verification commands executed in this pass

```bash
# Toolchain anchors
node -v
npm -v
cd hardhat && npx hardhat --version && cd ..
npx truffle version

# Prime size and deploy-path checks
npm run test:size
npm run test:prime:deploy-smoke
```

Observed outcomes:
- `test:size` passed and reported runtime + initcode size/headroom for Prime manager, discovery, and completion NFT.
- `test:prime:deploy-smoke` passed and validated canonical Prime deploy ordering, completion NFT capture, discovery-module wiring, optional ENS wiring branch, and artifact emission.
- `test:prime:unit` compilation step was attempted but did not produce terminal output within the non-interactive session window; no blocker evidence contradicted the already-resolved status findings above.
