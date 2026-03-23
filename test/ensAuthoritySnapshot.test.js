const { expectEvent } = require('@openzeppelin/test-helpers');

const ENSJobPages = artifacts.require('ENSJobPages');
const ENSJobPagesInspector = artifacts.require('ENSJobPagesInspector');
const MockENSRegistry = artifacts.require('MockENSRegistry');
const MockNameWrapper = artifacts.require('MockNameWrapper');
const MockPublicResolver = artifacts.require('MockPublicResolver');
const MockAGIJobManagerView = artifacts.require('MockAGIJobManagerView');
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

  it('accepts live-style resolvers that answer text() but do not advertise write interfaces', async () => {
    const { manager, pages } = await deployPages();
    await manager.setJob(11, employer, agent, 'ipfs://spec-11', { from: owner });

    const status = await pages.configurationStatus();
    assert.equal(status[0], true, 'configuration should remain green when resolver can be used operationally');
    assert.equal(status[7], true, 'text lookup is supported');
    assert.equal(status[8], false, 'setText ERC-165 advertisement is absent on the live resolver shape');
    assert.equal(status[9], false, 'setAuthorisation ERC-165 advertisement is absent on the live resolver shape');

    const receipt = await manager.callHandleHook(pages.address, 1, 11, { from: owner });
    await expectEvent.inTransaction(receipt.tx, pages, 'ENSHookProcessed', { hook: '1', jobId: '11', configured: true, success: true });
    assert.equal(await pages.effectiveJobEnsName(11), 'agijob-11.alpha.jobs.agi.eth');
  });

  it('exposes machine-readable inspector status for preview/effective/finalization surfaces', async () => {
    const { manager, pages } = await deployPages();
    const inspector = await ENSJobPagesInspector.new({ from: owner });
    await manager.setJob(9, employer, agent, 'ipfs://spec-9', { from: owner });
    await manager.callHandleHook(pages.address, 1, 9, { from: owner });
    await manager.callHandleHook(pages.address, 2, 9, { from: owner });
    await pages.replayLock(9, false, { from: owner });

    const report = await inspector.inspectJob.call(pages.address, 9, employer, agent, { from: owner });
    assert.equal(report.authoritySnapshotted, true);
    assert.equal(report.previewName, 'agijob-9.alpha.jobs.agi.eth');
    assert.equal(report.effectiveName, 'agijob-9.alpha.jobs.agi.eth');
    assert.equal(report.finalized, true);
  });
});
