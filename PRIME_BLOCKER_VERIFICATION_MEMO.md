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

- `AGIJobManagerPrime` runtime `24472` bytes (headroom `104`), initcode `29972` bytes (headroom `19180`)
- `AGIJobDiscoveryPrime` runtime `24505` bytes (headroom `71`), initcode `25106` bytes (headroom `24046`)
- `AGIJobCompletionNFT` runtime `3334` bytes (headroom `21242`), initcode `4177` bytes (headroom `44975`)
- `ENSJobPages` runtime `24576` bytes (headroom `0`), initcode `27366` bytes (headroom `21786`)
- `ENSJobPagesInspector` runtime `7597` bytes (headroom `16979`), initcode `7624` bytes (headroom `41528`)
- `ENSJobPagesMigrationHelper` runtime `3135` bytes (headroom `21441`), initcode `3230` bytes (headroom `45922`)

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

## 2026-03-16 addendum (this pass)

A fresh source audit was performed against the current checked-out baseline before proposing any additional patching.

- Re-verified deploy-path canonicalization in `hardhat/scripts/deploy.js` + Hardhat docs/package scripts (Prime targets only).
- Re-verified `DisputeAlreadyOpen` guard in `AGIJobManagerPrime.disputeJob()` and single-slot dispute accounting semantics.
- Re-verified commit-time authorization + reputation gating in `AGIJobDiscoveryPrime.commitApplication()`.
- Re-verified assignment-time snapshot fields and downstream consumption in completion/dispute/finalization paths.
- Re-verified `renounceOwnership()` disablement in both Prime contracts.
- Re-verified runtime+initcode gate logic in `scripts/check-bytecode-size.js`.

No new Prime blocker regressions were identified in the current baseline. ENS-side bytecode headroom is now explicitly tracked as part of size-gate outputs, including helper contracts intended for production migration operations.
