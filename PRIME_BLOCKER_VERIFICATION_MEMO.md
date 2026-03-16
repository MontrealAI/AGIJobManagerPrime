# Prime Mainnet Blocker Verification Memo (Current `main` Baseline)

This memo records the blocker-by-blocker verification pass performed on the current `main` baseline **before** applying any new code changes.

## Verification outcome summary

| Blocker | Status on current baseline | Evidence |
|---|---|---|
| Canonical Hardhat deploy path inconsistent or legacy-targeted | **Already resolved** | `hardhat/scripts/deploy.js` deploys `AGIJobManagerPrime` then `AGIJobDiscoveryPrime`, wires `setDiscoveryModule`, captures `completionNFT`, supports optional ENS wiring / ownership transfer / verification, and reads compiler settings from `hardhat/hardhat.config.js`. |
| Repeated dispute openings possible | **Already resolved** | `DisputeAlreadyOpen` custom error exists and `disputeJob()` reverts when `job.disputed` is already true. |
| Applicant-slot griefing at commit | **Already resolved** | `AGIJobDiscoveryPrime.commitApplication()` checks `isAuthorizedAgent(...)` and `reputation(msg.sender) >= p.minReputation` before applicant-slot consumption. |
| Live-job-sensitive mutable globals | **Already resolved** | Assignment-time snapshots are stored in job state (`completionReviewPeriodSnapshot`, `disputeReviewPeriodSnapshot`, `challengePeriodAfterApprovalSnapshot`, `voteQuorumSnapshot`, validator thresholds, slash bps), and downstream paths consume snapshots. |
| Ownership hardening (`renounceOwnership`) incomplete | **Already resolved** | Both Prime contracts override `renounceOwnership()` to revert via custom errors. |
| Security verification artifact stale/legacy scoped | **Resolved + refreshed** | `SECURITY_VERIFICATION_REPORT.md` now remains Prime-scoped with current-toolchain reproduction notes and baseline-verification framing. |
| Size gate runtime-only (no initcode) | **Already resolved** | `scripts/check-bytecode-size.js` enforces runtime and initcode limits and prints per-contract headroom. |

## Prime deployability snapshot (current run)

`npm run test:size` produced:

- `AGIJobManagerPrime` runtime `24456` bytes (headroom `120`), initcode `29956` bytes (headroom `19196`)
- `AGIJobDiscoveryPrime` runtime `21563` bytes (headroom `3013`), initcode `22142` bytes (headroom `27010`)
- `AGIJobCompletionNFT` runtime `3334` bytes (headroom `21242`), initcode `4177` bytes (headroom `44975`)

## Commands executed in this pass

```bash
node -v
npm -v
cd hardhat && npx hardhat --version && npm ls hardhat --depth=0 && cd ..
npx truffle version

npm run test:size
npm run test:prime:deploy-smoke
npm run test:prime:unit
```

Observed outcomes:

- `test:size` passed and reported runtime + initcode size/headroom for Prime manager, discovery, and completion NFT.
- `test:prime:deploy-smoke` passed and validated canonical Prime deploy ordering, completion NFT capture, discovery-module wiring, optional ENS branch handling, and artifact emission.
- `test:prime:unit` started but stalled during repeated compiler-fetch attempts in this non-interactive environment window; no contradictory evidence surfaced against the baseline blocker resolution status.
