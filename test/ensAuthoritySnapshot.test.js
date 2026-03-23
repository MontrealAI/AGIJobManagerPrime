const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const ENSJobPages = artifacts.require('ENSJobPages');
const ENSJobPagesInspector = artifacts.require('ENSJobPagesInspector');
const MockENSRegistry = artifacts.require('MockENSRegistry');
const MockNameWrapper = artifacts.require('MockNameWrapper');
const MockPublicResolver = artifacts.require('MockPublicResolver');
const MockPublicResolverNoAuthRead = artifacts.require('MockPublicResolverNoAuthRead');
const MockPublicResolverApprove = artifacts.require('MockPublicResolverApprove');
const MockAGIJobManagerView = artifacts.require('MockAGIJobManagerView');
const MockAGIJobManagerPrimeFallback = artifacts.require('MockAGIJobManagerPrimeFallback');
const MockNoSupportsInterface = artifacts.require('MockNoSupportsInterface');

const { namehash, subnode } = require('./helpers/ens');

contract('ENSJobPages authority snapshots', (accounts) => {
  const [owner, employer, agent] = accounts;
  const ROOT_V1 = 'alpha.jobs.agi.eth';
  const ROOT_V2 = 'beta.jobs.agi.eth';

  async function deployPages(resolverOverride) {
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const resolver = resolverOverride || await MockPublicResolver.new({ from: owner });
    const manager = await MockAGIJobManagerView.new({ from: owner });
    const pages = await ENSJobPages.new(ens.address, wrapper.address, resolver.address, namehash(ROOT_V1), ROOT_V1, { from: owner });
    await pages.setJobManager(manager.address, { from: owner });
    await ens.setOwner(namehash(ROOT_V1), pages.address, { from: owner });
    return { ens, wrapper, resolver, manager, pages };
  }

  it('separates preview from effective identity and preserves authoritative root after root mutation', async () => {
    const { ens, resolver, manager, pages } = await deployPages();
    await manager.setJob(7, employer, agent, 'ipfs://spec-7', { from: owner });
    await manager.callHandleHook(pages.address, 1, 7, { from: owner });

    assert.equal(await pages.previewJobEnsName(7), 'agijob-7.alpha.jobs.agi.eth');
    assert.equal(await pages.effectiveJobEnsName(7), 'agijob-7.alpha.jobs.agi.eth');

    const nodeV1 = subnode(namehash(ROOT_V1), 'agijob-7');
    assert.equal(await pages.effectiveJobEnsNode(7), nodeV1);
    assert.equal(await resolver.text(nodeV1, 'agijobs.spec.public'), 'ipfs://spec-7');

    await ens.setOwner(namehash(ROOT_V2), pages.address, { from: owner });
    await pages.setJobsRoot(namehash(ROOT_V2), ROOT_V2, { from: owner });

    assert.equal(await pages.previewJobEnsName(7), 'agijob-7.beta.jobs.agi.eth');
    assert.equal(await pages.effectiveJobEnsName(7), 'agijob-7.alpha.jobs.agi.eth');
    assert.equal(await pages.jobEnsName(7), 'agijob-7.alpha.jobs.agi.eth', 'compat getter should prefer authority');
  });

  it('supports exact-label legacy import and idempotent repair flows', async () => {
    const { resolver, manager, pages } = await deployPages();
    const legacyLabel = 'agijob42';
    const legacyNode = subnode(namehash(ROOT_V1), legacyLabel);

    await manager.setJob(42, employer, agent, 'ipfs://legacy-spec', { from: owner });
    await manager.setCompletionURI(42, 'ipfs://legacy-completion', { from: owner });

    const receipt = await pages.migrateLegacyWrappedJobPage(42, legacyLabel, { from: owner });
    await expectEvent(receipt, 'JobAuthoritySnapshotted', { jobId: '42', label: legacyLabel });
    assert.equal(await pages.effectiveJobEnsName(42), `${legacyLabel}.${ROOT_V1}`);
    assert.equal(await pages.effectiveJobEnsNode(42), legacyNode);

    await pages.repairAuthoritySnapshot(42, legacyLabel, { from: owner });
    await pages.repairTexts(42, { from: owner });
    await pages.repairAuthorisations(42, { from: owner });

    assert.equal(await resolver.text(legacyNode, 'agijobs.spec.public'), 'ipfs://legacy-spec');
    assert.equal(await resolver.text(legacyNode, 'agijobs.completion.public'), 'ipfs://legacy-completion');
    assert.equal(await resolver.isAuthorised(legacyNode, employer), true);
    assert.equal(await resolver.isAuthorised(legacyNode, agent), true);
  });

  it('supports explicit legacy migration when the manager does not expose V1 views', async () => {
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const resolver = await MockPublicResolver.new({ from: owner });
    const fallbackManager = await MockAGIJobManagerPrimeFallback.new({ from: owner });
    const pages = await ENSJobPages.new(ens.address, wrapper.address, resolver.address, namehash(ROOT_V1), ROOT_V1, { from: owner });
    const legacyLabel = 'agijob77';
    const legacyNode = subnode(namehash(ROOT_V1), legacyLabel);

    await pages.setJobManager(fallbackManager.address, { from: owner });
    await ens.setOwner(namehash(ROOT_V1), wrapper.address, { from: owner });
    await wrapper.setOwner(web3.utils.toBN(namehash(ROOT_V1)), owner, { from: owner });
    await wrapper.setApprovalForAll(pages.address, true, { from: owner });

    const receipt = await pages.migrateLegacyWrappedJobPageExplicit(
      77,
      legacyLabel,
      employer,
      agent,
      true,
      'ipfs://legacy-spec-77',
      'ipfs://legacy-completion-77',
      { from: owner }
    );

    await expectEvent(receipt, 'LegacyJobPageMigrated', { jobId: '77', label: legacyLabel });
    assert.equal(await pages.effectiveJobEnsNode(77), legacyNode);
    assert.equal(await resolver.text(legacyNode, 'agijobs.spec.public'), 'ipfs://legacy-spec-77');
    assert.equal(await resolver.text(legacyNode, 'agijobs.completion.public'), 'ipfs://legacy-completion-77');
  });

  it('requires explicit rootVersion repair once multiple root versions exist', async () => {
    const { ens, manager, pages } = await deployPages();
    await manager.setJob(11, employer, agent, 'ipfs://spec-11', { from: owner });
    await pages.setJobsRoot(namehash(ROOT_V2), ROOT_V2, { from: owner });

    await expectRevert.unspecified(pages.repairAuthoritySnapshot(11, 'agijob-11', { from: owner }));
    await pages.repairAuthoritySnapshotExplicit(11, 'agijob-11', 1, { from: owner });
    assert.equal(await pages.effectiveJobEnsName(11), 'agijob-11.alpha.jobs.agi.eth');

    await ens.setOwner(namehash(ROOT_V2), pages.address, { from: owner });
  });

  it('blocks no-label authority repair for ambiguous legacy jobs and rejects conflicting re-snapshots', async () => {
    const { manager, pages } = await deployPages();
    await manager.setJob(14, employer, agent, 'ipfs://spec-14', { from: owner });

    await expectRevert.unspecified(pages.repairAuthoritySnapshot(14, '', { from: owner }));
    await pages.repairAuthoritySnapshot(14, 'agijob-14', { from: owner });
    await expectRevert.unspecified(pages.repairAuthoritySnapshot(14, 'otherjob-14', { from: owner }));
  });

  it('keeps handleHook usable for unchanged Prime-style managers without V1 getters', async () => {
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const resolver = await MockPublicResolver.new({ from: owner });
    const fallbackManager = await MockAGIJobManagerPrimeFallback.new({ from: owner });
    const pages = await ENSJobPages.new(ens.address, wrapper.address, resolver.address, namehash(ROOT_V1), ROOT_V1, { from: owner });
    await pages.setJobManager(fallbackManager.address, { from: owner });
    await ens.setOwner(namehash(ROOT_V1), pages.address, { from: owner });
    await fallbackManager.setJob(5, employer, agent, { from: owner });

    const createReceipt = await fallbackManager.callHandleHook(pages.address, 1, 5, { from: owner });
    await expectEvent.inTransaction(createReceipt.tx, pages, 'ENSHookBestEffortFailure', { hook: '1', jobId: '5', operation: web3.utils.padRight(web3.utils.asciiToHex('SPEC_URI_UNAVAILABLE'), 64) });
    assert.equal(await pages.jobEnsIssued(5), true, 'authority + node issuance should not depend on spec getter availability');
    assert.equal(await pages.jobEnsReady(5), false, 'ready must not overclaim without observed spec text');

    await fallbackManager.callHandleHook(pages.address, 2, 5, { from: owner });
    const node = await pages.effectiveJobEnsNode(5);
    assert.equal(await resolver.isAuthorised(node, employer), true, 'create should still authorise employer');
    assert.equal(await resolver.isAuthorised(node, agent), true, 'fallback assign should still authorise assigned agent');

    await pages.repairSpecTextExplicit(5, 'ipfs://spec-5', { from: owner });
    assert.equal(await pages.jobEnsReady(5), true, 'ready becomes true only after observed base metadata is present');
  });

  it('keeps Prime-compatible hook ABI while making resolver incompatibility explicit', async () => {
    const badResolver = await MockNoSupportsInterface.new({ from: owner });
    const { manager, pages } = await deployPages(badResolver);
    await manager.setJob(3, employer, agent, 'ipfs://spec-3', { from: owner });

    const status = await pages.configurationStatus();
    assert.equal(status[0], false, 'configuration should not be ready when resolver lacks a readable text surface');
    assert.equal(status[7], false, 'resolver text support should be explicit');
    assert.equal(status[8], false, 'resolver setText support should be explicit');
    assert.equal(status[9], false, 'resolver setAuthorisation support should be explicit');

    const receipt = await manager.callHandleHook(pages.address, 1, 3, { from: owner });
    await expectEvent.inTransaction(receipt.tx, pages, 'ENSHookSkipped', { hook: '1', jobId: '3' });
  });

  it('exposes machine-readable inspector status for preview/effective/finalization surfaces', async () => {
    const { manager, pages } = await deployPages();
    const inspector = await ENSJobPagesInspector.new({ from: owner });
    await manager.setJob(9, employer, agent, 'ipfs://spec-9', { from: owner });
    await manager.callHandleHook(pages.address, 1, 9, { from: owner });
    await manager.callHandleHook(pages.address, 2, 9, { from: owner });
    await pages.replayLock(9, false, { from: owner });

    const report = await inspector.inspectJob.call(pages.address, 9, employer, agent, { from: owner, gas: 8000000 });
    assert.equal(report.authoritySnapshotted, true);
    assert.equal(report.previewName, 'agijob-9.alpha.jobs.agi.eth');
    assert.equal(report.effectiveName, 'agijob-9.alpha.jobs.agi.eth');
    assert.equal(report.finalized, true);
    assert.equal(report.managerSupportsV1Views, true);
    assert.equal(report.metadataAutoWriteSupported, true);
    assert.equal(report.keeperRequired, false);
    assert.equal(report.managerMode.toString(), '2');
  });

  it('inspector keeps auth-read absence separate from explicit false', async () => {
    const { manager, pages } = await deployPages(await MockPublicResolverNoAuthRead.new({ from: owner }));
    const inspector = await ENSJobPagesInspector.new({ from: owner });
    await manager.setJob(12, employer, agent, 'ipfs://spec-12', { from: owner });
    await manager.callHandleHook(pages.address, 1, 12, { from: owner });

    const report = await inspector.inspectJob.call(pages.address, 12, employer, agent, { from: owner, gas: 8000000 });
    assert.equal(report.authReadSupported, false);
    assert.equal(report.authObservationIncomplete, true);
    assert.equal(report.authorisationsAsExpected, false, 'unknown auth state must not be reported as healthy');
  });

  it('inspector observes modern approve/isApprovedFor resolver family without legacy isAuthorised guesses', async () => {
    const modernResolver = await MockPublicResolverApprove.new({ from: owner });
    const { manager, pages } = await deployPages(modernResolver);
    const inspector = await ENSJobPagesInspector.new({ from: owner });

    await manager.setJob(13, employer, agent, 'ipfs://spec-13', { from: owner });
    await manager.callHandleHook(pages.address, 1, 13, { from: owner });
    await manager.callHandleHook(pages.address, 2, 13, { from: owner });

    const node = await pages.effectiveJobEnsNode(13);
    assert.equal(await modernResolver.isApprovedFor(node, employer), true);
    assert.equal(await modernResolver.isApprovedFor(node, agent), true);

    const report = await inspector.inspectJob.call(pages.address, 13, employer, agent, { from: owner, gas: 8000000 });
    assert.equal(report.authReadSupported, true);
    assert.equal(report.employerAuthorisedObserved, true);
    assert.equal(report.agentAuthorisedObserved, true);
    assert.equal(report.authorisationsAsExpected, true);
    assert.equal(report.managerSupportsV1Views, true);
    assert.equal(report.metadataAutoWriteSupported, true);
    assert.equal(report.keeperRequired, false);
    assert.equal(report.managerMode.toString(), '2');
  });
});
