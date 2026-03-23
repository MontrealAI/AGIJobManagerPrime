# CHANGE MINIMIZATION PLAN

## Selected architecture

**Option B with helper-style read hardening, but no Prime runtime changes.**

## Why this is the smallest safe patch set

1. Keep `AGIJobManagerPrime` bytecode unchanged.
2. Preserve `handleHook(uint8,uint256)` wire compatibility.
3. Patch only ENS-side authority/auth tooling where the real defects lived.
4. Use read-heavy inspector + scripts/docs to expose compatibility mode instead of bloating Prime.

## Patch scope

- `contracts/ens/ENSJobPages.sol`
  - fix resolver auth write capability detection;
  - support both legacy `setAuthorisation` and newer `approve(bytes32,address,bool)` write paths.
- `contracts/ens/ENSJobPagesInspector.sol`
  - stop probing guessed external `isAuthorised(bytes32,address)`;
  - read legacy `authorisations(...)` and modern `isApprovedFor(...)` / `isApprovedForAll(...)` surfaces instead;
  - expose machine-readable manager compatibility status.
- `contracts/test/*`
  - add resolver-family coverage for modern approve/isApprovedFor flows.
- `scripts/ens/*`
  - align auth probing and compatibility labeling with actual resolver families and unchanged-Prime lean mode.
- `hardhat/scripts/deploy-ens-job-pages.js`
  - require explicit `JOB_MANAGER` on mainnet.
- `README.md`, `hardhat/README.md`, `docs/ENS/*`
  - make preview/effective and automatic-vs-keeper-assisted semantics explicit.

## Rejected smaller alternatives

- **Docs-only fix:** rejected because resolver capability/auth verification was genuinely unsafe.
- **Inspector-only fix:** rejected because ENSJobPages itself still assumed the wrong auth write capability model.
- **Prime change:** rejected because unchanged Prime already provides enough data for truthful authority issuance plus explicit repair flows.
