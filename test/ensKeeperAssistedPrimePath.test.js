const assert = require('assert');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const ENSJobPages = artifacts.require('ENSJobPages');
const UriUtils = artifacts.require('UriUtils');
const BondMath = artifacts.require('BondMath');
const ReputationMath = artifacts.require('ReputationMath');
const ENSOwnership = artifacts.require('ENSOwnership');
const MockERC20 = artifacts.require('MockERC20');
const MockENSRegistry = artifacts.require('MockENSRegistry');
const MockNameWrapper = artifacts.require('MockNameWrapper');
const MockPublicResolver = artifacts.require('MockPublicResolver');
const MockERC721 = artifacts.require('MockERC721');

const { namehash, subnode } = require('./helpers/ens');

const ZERO32 = `0x${'00'.repeat(32)}`;
const EMPTY = [];
const ROOT = 'alpha.jobs.agi.eth';

contract('Prime keeper-assisted ENS authority path', (accounts) => {
  const [owner, employer, agent, validator] = accounts;

  before(async () => {
    const uriUtils = await UriUtils.new({ from: owner });
    const bondMath = await BondMath.new({ from: owner });
    const reputationMath = await ReputationMath.new({ from: owner });
    const ensOwnership = await ENSOwnership.new({ from: owner });

    AGIJobManagerPrime.link('UriUtils', uriUtils.address);
    AGIJobManagerPrime.link('BondMath', bondMath.address);
    AGIJobManagerPrime.link('ReputationMath', reputationMath.address);
    AGIJobManagerPrime.link('ENSOwnership', ensOwnership.address);
  });

  it('hydrates authoritative ENS state from Prime events without changing Prime runtime wiring', async () => {
    const token = await MockERC20.new({ from: owner });
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const resolver = await MockPublicResolver.new({ from: owner });

    const manager = await AGIJobManagerPrime.new(
      token.address,
      'ipfs://base/',
      owner,
      owner,
      [ZERO32, ZERO32, ZERO32, ZERO32],
      [ZERO32, ZERO32],
      { from: owner }
    );

    const pages = await ENSJobPages.new(ens.address, wrapper.address, resolver.address, namehash(ROOT), ROOT, { from: owner });
    await pages.setJobManager(manager.address, { from: owner });
    await ens.setOwner(namehash(ROOT), pages.address, { from: owner });

    // Deliberately do not wire Prime -> ENSJobPages. This proves the manager-unchanged keeper path.
    assert.equal(await manager.ensJobPages(), '0x0000000000000000000000000000000000000000');

    await manager.addAdditionalAgent(agent, { from: owner });
    await manager.addAdditionalValidator(validator, { from: owner });
    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });

    const agiType = await MockERC721.new({ from: owner });
    await agiType.mint(agent, { from: owner });
    await manager.addOrUpdateAGIType(agiType.address, 90, { from: owner });

    for (const actor of [employer, agent, validator]) {
      await token.mint(actor, web3.utils.toWei('100'), { from: owner });
      await token.approve(manager.address, web3.utils.toWei('100'), { from: actor });
    }

    const createTx = await manager.createJob('ipfs://spec-keeper', web3.utils.toWei('10'), 100, 'details', { from: employer });
    const created = createTx.logs.find((log) => log.event === 'JobCreated');
    const jobId = created.args.jobId.toNumber();
    assert.equal(created.args.jobSpecURI, 'ipfs://spec-keeper');

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agent });
    const completionTx = await manager.requestJobCompletion(jobId, 'ipfs://completion-keeper', { from: agent });
    const completion = completionTx.logs.find((log) => log.event === 'JobCompletionRequested');
    assert.equal(completion.args.jobCompletionURI, 'ipfs://completion-keeper');

    // Keeper/operator hydrates ENS using existing Prime events + existing ENS owner-callable endpoints.
    await pages.createJobPage(jobId, created.args.employer, created.args.jobSpecURI, { from: owner });
    await pages.onAgentAssigned(jobId, agent, { from: owner });
    await pages.onCompletionRequested(jobId, completion.args.jobCompletionURI, { from: owner });

    const expectedNode = subnode(namehash(ROOT), 'agijob-0');
    assert.equal(await pages.effectiveJobEnsName(jobId), 'agijob-0.alpha.jobs.agi.eth');
    assert.equal(await pages.effectiveJobEnsNode(jobId), expectedNode);
    assert.equal(await resolver.text(expectedNode, 'agijobs.spec.public'), 'ipfs://spec-keeper');
    assert.equal(await resolver.text(expectedNode, 'agijobs.completion.public'), 'ipfs://completion-keeper');

    // Non-blocking settlement invariant: Prime lifecycle works independently of ENS automation wiring.
    const core = await manager.getJobCore(jobId);
    assert.equal(core.completed, true, 'completion request should succeed even without ENS hook wiring');
  });
});
