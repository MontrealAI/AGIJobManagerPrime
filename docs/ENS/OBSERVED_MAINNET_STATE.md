# Observed Mainnet State

_Observed on Ethereum mainnet on 2026-03-23 UTC using `scripts/ens/audit-mainnet.ts` and `scripts/ens/inventory-job-pages.ts` against `https://ethereum.publicnode.com`. Chain state wins over repo prose._

## Proven live state

### ENSJobPages at `0x97E03F7BFAC116E558A25C8f09aEf09108a2779d`

- owner: `0xa9eD0539c2fbc5C6BC15a2E168bd9BCd07c01201`
- ENS registry: `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e`
- NameWrapper: `0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401`
- configured public resolver: `0xF29100983E058B709F3D539b0c765937B804AC15`
- jobs root name: `alpha.jobs.agi.eth`
- jobs root node: `0xc164c9558a3c429519a9b2eba9f650025731fccc46b3a5664283bcab84f7e690`
- wired job manager: `0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e`
- job label prefix: `agijob-`
- `configLocked = false`
- `useEnsJobTokenURI = false`

### AGIJobManagerPrime at `0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e`

- owner: `0xa9eD0539c2fbc5C6BC15a2E168bd9BCd07c01201`
- discovery module: `0xd5EF1dde7Ac60488f697ff2A7967a52172A78F29`
- ENS hook target: `0x97E03F7BFAC116E558A25C8f09aEf09108a2779d`
- `nextJobId = 0`

### Root integrity and wrapped-root readiness

- ENSIP-15-normalized root input `alpha.jobs.agi.eth` namehashes to `0xc164c9558a3c429519a9b2eba9f650025731fccc46b3a5664283bcab84f7e690`.
- Live ENS root owner is the NameWrapper, so the root is wrapped.
- Wrapped root owner is `0xd57243B80FBc5CFB2560E5a644651FEcd7Dc2512`.
- `getApproved(rootTokenId) = 0x0000000000000000000000000000000000000000`
- `isApprovedForAll(wrappedOwner, ENSJobPages) = true`
- Operationally, wrapper authorization is ready for the currently wired ENSJobPages address.

### Resolver compatibility

- The configured resolver supports text reads: `supportsInterface(0x59d1d43c) = true`.
- The configured resolver does **not** report support for text writes: `supportsInterface(0x10f13a8c) = false`.
- The configured resolver does **not** report support for resolver authorisations: `supportsInterface(0x304e6ade) = false`.

## First-class blockers proven from chain

1. The live ENSJobPages deployment does **not** expose the new authoritative read/status surface. Calls to:
   - `validateConfiguration()`
   - `configurationStatus()`
   - `jobAuthorityInfo(uint256)`
   currently revert on mainnet.
2. The live public resolver does not advertise `setText` or `setAuthorisation` support over ERC-165. The replacement ENSJobPages keeps those write-capability checks as hard configuration gates so hook processing does not falsely report success while metadata/authorisation writes are impossible.
3. There are currently no Prime jobs on the observed manager deployment (`nextJobId = 0`), so there is no historical inventory to migrate yet on this address pair.

## Compatibility conclusion

- The **manager wiring** is correct: Prime points to the intended ENSJobPages and ENSJobPages points back to Prime.
- The **current live ENSJobPages implementation** is not yet the authoritative snapshotting/status implementation shipped in this repository.
- Cutover therefore requires an ENSJobPages replacement deployment and owner-side rewiring, while keeping `AGIJobManagerPrime` runtime bytecode unchanged.

## Machine-readable artifacts

- `scripts/ens/output/audit-mainnet.json`
- `scripts/ens/output/inventory-job-pages.json`
- `scripts/ens/output/repair-job-page.json`

## Re-run commands

- `MAINNET_RPC_URL=https://ethereum.publicnode.com node scripts/ens/audit-mainnet.ts`
- `MAINNET_RPC_URL=https://ethereum.publicnode.com MAX_JOBS=64 node scripts/ens/inventory-job-pages.ts`
- `MAINNET_RPC_URL=https://ethereum.publicnode.com JOB_ID=0 node scripts/ens/repair-job-page.ts`
