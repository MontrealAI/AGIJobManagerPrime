# Deployment artifacts

This directory holds committed deployment- and cutover-related artifacts that are generated from repository scripts.

## ENS Phase 0 mainnet authority / inventory snapshot

Generate the latest read-only ENS Phase 0 snapshot with:

```bash
npm run ens:phase0:mainnet
```

Default outputs from the script:

- `docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-2026-03-22.json`
- `docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-2026-03-22.md`

The snapshot is intended to capture:

- current `AGIJobManagerPrime.ensJobPages`,
- `nextJobId`,
- ENS root / NameWrapper authority state,
- active `ENSJobPages` configuration (when the live contract exposes it),
- first-window job inventory and repair candidate buckets.

If your environment cannot reach a mainnet RPC endpoint, re-run the command from a network-enabled environment before cutover and commit the generated files alongside the deployment PR.
