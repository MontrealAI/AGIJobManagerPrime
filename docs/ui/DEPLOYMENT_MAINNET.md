# Mainnet Deployment Registry (Prime stack)

- Updated for Prime standalone canon on: 2026-03-24
- Chain ID: `1` (Ethereum mainnet)
- Explorer: https://etherscan.io

## Canonical Prime addresses

| Contract | Address | Status | Notes |
| --- | --- | --- | --- |
| AGIJobManagerPrime | `0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e` | Active | Settlement kernel. |
| AGIJobDiscoveryPrime | `0xd5EF1dde7Ac60488f697ff2A7967a52172A78F29` | Active | Premium discovery/procurement layer. |
| ENSJobPages | `0x703011EF1C6E4277587eFe150e6cd74cA18F0069` | Active | ENS job-page authority used by Prime console. |
| FreeTrialSubdomainRegistrarIdentity | `0x7811993CbcCa3b8bb35a3d919F3BA59eeFbeAA9a` | Active | Combined registration + identity route. |

## Historical/superseded references (for audits only)

These addresses are kept only for historical traceability and must not be treated as current Prime defaults.

| Contract | Address | Status |
| --- | --- | --- |
| AGIJobManager (beta) | `0xB3AAeb69b630f0299791679c063d68d6687481d1` | Superseded |
| ENSJobPages (legacy) | `0xc19A84D10ed28c2642EfDA532eC7f3dD88E5ed94` | Superseded |

## Operator policy

- The standalone canonical artifact is `ui/agijobmanager_genesis_job_mainnet_2026-03-05-v42.html`.
- Operator runbook: `docs/ui/GENESIS_JOB_MAINNET_HTML_UI.md`.
- If any UI copy conflicts with chain reads, prefer direct on-chain getters/events and this Prime registry.
