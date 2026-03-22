# ENS mainnet cutover and rollback

## Cutover
1. Deploy fresh `ENSJobPages` with `jobsRootName=alpha.jobs.agi.eth` and verify `namehash(rootName) == jobsRootNode`.
2. Run `node hardhat/scripts/validate-ens-cutover.js` against the new `AGIJobManagerPrime` and `ENSJobPages`. The script refuses cutover if interface support, root namehash, resolver wiring, or wrapped-root approval checks fail.
3. If the jobs root is wrapped, the wrapped-root owner must call `setApprovalForAll(newEnsJobPages, true)` before cutover.
4. Call `ENSJobPages.setJobManager(newPrime)` and confirm `validateConfiguration() == 0`.
5. Call `AGIJobManagerPrime.setEnsJobPages(newEnsJobPages)`.
6. Optionally enable ENS-backed completion NFTs via `AGIJobManagerPrime.setUseEnsJobTokenURI(true)` once `jobEnsIssued(jobId)` is observable for new jobs.
7. For any missed best-effort updates, replay with `AGIJobManagerPrime.syncEnsHook(...)` or `ENSJobPages.sync*FromManager(...)`.

## Rollback
1. Disable new ENS side effects by calling `AGIJobManagerPrime.setEnsJobPages(address(0))`.
2. Leave the new deployment intact for forensic inspection; do not destroy historical labels.
3. Re-point to the prior replacement deployment only after re-running `validate-ens-cutover.js`.
4. If NFT ENS URIs were enabled, disable them with `setUseEnsJobTokenURI(false)` until the replacement is healthy again.
