# Changelog

## Unreleased

### Prime mainnet hardening
- Disabled `renounceOwnership()` on `AGIJobManagerPrime` to preserve explicit owner-operated governance continuity.
- Added single-open-dispute enforcement via `DisputeAlreadyOpen` in `disputeJob`.
- Added live-job parameter freezing for completion/dispute/challenge timing by snapshotting review windows at assignment time.
- Extended Prime tests to cover owner-control hardening, dispute re-open prevention, and live-job timing freeze semantics.
- Extended bytecode guardrail script to report and enforce both runtime bytecode (EIP-170) and initcode (EIP-3860) limits, including explicit headroom.
- Hardened the Prime mainnet HTML console so refunded employer settlements render as terminal, and commitment notebook helpers now require the connected wallet/finalist fields before computing or saving entries.
