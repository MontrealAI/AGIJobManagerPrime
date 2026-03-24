const { expectRevert } = require('@openzeppelin/test-helpers');

const ENSJobPages = artifacts.require('ENSJobPages');
const ENSJobPagesMigrationHelper = artifacts.require('ENSJobPagesMigrationHelper');
const MockENSRegistry = artifacts.require('MockENSRegistry');
const MockNameWrapper = artifacts.require('MockNameWrapper');
const MockPublicResolver = artifacts.require('MockPublicResolver');
const MockAGIJobManagerView = artifacts.require('MockAGIJobManagerView');

const { namehash, subnode } = require('./helpers/ens');

contract('ENSJobPagesMigrationHelper', (accounts) => {
  const [owner, employer, agent, outsider] = accounts;
  const ROOT = 'alpha.jobs.agi.eth';

  async function setup() {
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const resolver = await MockPublicResolver.new({ from: owner });
    const manager = await MockAGIJobManagerView.new({ from: owner });
    const pages = await ENSJobPages.new(ens.address, wrapper.address, resolver.address, namehash(ROOT), ROOT, { from: owner });
    const helper = await ENSJobPagesMigrationHelper.new({ from: owner });
    await pages.setJobManager(manager.address, { from: owner });
    return { ens, wrapper, resolver, manager, pages, helper };
  }

  it('adopts existing unmanaged unwrapped legacy nodes and replays create', async () => {
    const { ens, manager, pages, helper, resolver } = await setup();
    const label = 'agijob-7';
    const node = subnode(namehash(ROOT), label);

    await ens.setOwner(namehash(ROOT), helper.address, { from: owner });
    await ens.setSubnodeRecord(namehash(ROOT), web3.utils.keccak256(label), outsider, resolver.address, 0, { from: owner });
    await manager.setJob(7, employer, agent, 'ipfs://legacy-spec-7', { from: owner });
    await pages.transferOwnership(helper.address, { from: owner });

    await helper.migrateLegacyJobPageExplicit(pages.address, 7, label, 1, employer, 'ipfs://legacy-spec-7', { from: owner });

    assert.equal(await ens.owner(node), pages.address, 'node ownership should be migrated to ENSJobPages');
    assert.equal(await resolver.text(node, 'agijobs.spec.public'), 'ipfs://legacy-spec-7');
  });

  it('adopts unmanaged unwrapped nodes when ENSJobPages already controls the parent root', async () => {
    const { ens, manager, pages, helper, resolver } = await setup();
    const label = 'agijob-17';
    const node = subnode(namehash(ROOT), label);

    await ens.setOwner(namehash(ROOT), pages.address, { from: owner });
    await ens.setSubnodeRecord(namehash(ROOT), web3.utils.keccak256(label), outsider, resolver.address, 0, { from: owner });
    await manager.setJob(17, employer, agent, 'ipfs://legacy-spec-17', { from: owner });
    await pages.transferOwnership(helper.address, { from: owner });

    await helper.migrateLegacyJobPageExplicit(pages.address, 17, label, 1, employer, 'ipfs://legacy-spec-17', { from: owner });
    assert.equal(await ens.owner(node), pages.address, 'node should be reclaimed through ENSJobPages parent control path');
  });

  it('adopts wrapped legacy nodes through wrapper subnode rewrite', async () => {
    const { ens, wrapper, manager, pages, helper } = await setup();
    const label = 'agijob-8';
    const node = subnode(namehash(ROOT), label);

    await ens.setOwner(namehash(ROOT), wrapper.address, { from: owner });
    await wrapper.setOwner(web3.utils.toBN(namehash(ROOT)), helper.address, { from: owner });
    await wrapper.setOwner(web3.utils.toBN(node), outsider, { from: owner });
    await ens.setOwner(node, wrapper.address, { from: owner });
    await manager.setJob(8, employer, agent, 'ipfs://legacy-spec-8', { from: owner });
    await pages.transferOwnership(helper.address, { from: owner });

    await helper.migrateLegacyJobPageExplicit(pages.address, 8, label, 1, employer, 'ipfs://legacy-spec-8', { from: owner });

    assert.equal(await wrapper.ownerOf(web3.utils.toBN(node)), pages.address, 'wrapped token owner should be helper target');
  });

  it('adopts wrapped nodes when wrapped parent control is on ENSJobPages', async () => {
    const { ens, wrapper, manager, pages, helper } = await setup();
    const label = 'agijob-18';
    const node = subnode(namehash(ROOT), label);

    await ens.setOwner(namehash(ROOT), wrapper.address, { from: owner });
    await wrapper.setOwner(web3.utils.toBN(namehash(ROOT)), pages.address, { from: owner });
    await wrapper.setApproved(web3.utils.toBN(namehash(ROOT)), owner, { from: owner });
    await wrapper.setOwner(web3.utils.toBN(node), outsider, { from: owner });
    await ens.setOwner(node, wrapper.address, { from: owner });
    await manager.setJob(18, employer, agent, 'ipfs://legacy-spec-18', { from: owner });
    await pages.transferOwnership(helper.address, { from: owner });

    await helper.migrateLegacyJobPageExplicit(pages.address, 18, label, 1, employer, 'ipfs://legacy-spec-18', { from: owner });
    assert.equal(await wrapper.ownerOf(web3.utils.toBN(node)), pages.address, 'node should be reclaimed by ENSJobPages wrapped-root control');
  });

  it('fails with explicit AdoptionBlocked when neither wrapped authority nor helper-owned parent exists', async () => {
    const { ens, manager, pages, helper } = await setup();
    await ens.setOwner(namehash(ROOT), outsider, { from: owner });
    await manager.setJob(9, employer, agent, 'ipfs://legacy-spec-9', { from: owner });
    await pages.transferOwnership(helper.address, { from: owner });

    await expectRevert.unspecified(
      helper.migrateLegacyJobPageExplicit(pages.address, 9, 'agijob-9', 1, employer, 'ipfs://legacy-spec-9', { from: owner }),
    );
  });
});
