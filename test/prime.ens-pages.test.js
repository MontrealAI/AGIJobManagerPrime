const assert = require('assert');
const { time } = require('@openzeppelin/test-helpers');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const UriUtils = artifacts.require('UriUtils');
const BondMath = artifacts.require('BondMath');
const ReputationMath = artifacts.require('ReputationMath');
const ENSOwnership = artifacts.require('ENSOwnership');
const MockERC20 = artifacts.require('MockERC20');
const MockERC721 = artifacts.require('MockERC721');
const MockENSJobPages = artifacts.require('MockENSJobPages');
const MockNoSupportsInterface = artifacts.require('MockNoSupportsInterface');

const ZERO32 = `0x${'00'.repeat(32)}`;
const EMPTY = [];

contract('AGIJobManagerPrime ENS push hooks', (accounts) => {
  const [owner, employer, agent, validator] = accounts;
  let token;
  let manager;
  let ensJobPages;

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

  beforeEach(async () => {
    token = await MockERC20.new({ from: owner });
    manager = await AGIJobManagerPrime.new(
      token.address,
      'ipfs://base/',
      owner,
      owner,
      [ZERO32, ZERO32, ZERO32, ZERO32],
      [ZERO32, ZERO32],
      { from: owner }
    );
    ensJobPages = await MockENSJobPages.new({ from: owner });
    await manager.setEnsJobPages(ensJobPages.address, { from: owner });
    await manager.setUseEnsJobTokenURI(true, { from: owner });
    await manager.addAdditionalAgent(agent, { from: owner });
    await manager.addAdditionalValidator(validator, { from: owner });
    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });

    const agiType = await MockERC721.new({ from: owner });
    await agiType.mint(agent, { from: owner });
    await manager.addOrUpdateAGIType(agiType.address, 92, { from: owner });

    for (const actor of [employer, agent, validator]) {
      await token.mint(actor, web3.utils.toWei('1000'), { from: owner });
      await token.approve(manager.address, web3.utils.toWei('1000'), { from: actor });
    }
  });

  it('emits observable push-hook results and mints ens:// URIs only when issued', async () => {
    const createTx = await manager.createJob('ipfs://spec', web3.utils.toWei('10'), 100, 'details', { from: employer });
    const jobId = createTx.logs.find((log) => log.event === 'JobCreated').args.jobId.toNumber();
    const createHook = createTx.logs.find((log) => log.event === 'EnsHookCallResult');
    assert.equal(createHook.args.hook.toString(), '1');
    assert.equal(createHook.args.success, true);
    assert.equal(await ensJobPages.lastSpecURI(), 'ipfs://spec');

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agent });
    assert.equal((await ensJobPages.assignCalls()).toString(), '1');
    assert.equal(await ensJobPages.lastAgent(), agent);

    await manager.requestJobCompletion(jobId, 'ipfs://completion', { from: agent });
    assert.equal((await ensJobPages.completionCalls()).toString(), '1');

    await manager.validateJob(jobId, '', EMPTY, { from: validator });
    await time.increase(2);
    const finalizeTx = await manager.finalizeJob(jobId, { from: employer });
    const issued = finalizeTx.logs.find((log) => log.event === 'NFTIssued');
    assert.equal(issued.args.tokenURI, 'ens://agijob-0.alpha.jobs.agi.eth');
  });

  it('rejects incompatible ENSJobPages wiring and supports owner repair syncs', async () => {
    const incompatible = await MockNoSupportsInterface.new({ from: owner });
    try {
      await manager.setEnsJobPages(incompatible.address, { from: owner });
      assert.fail('expected revert');
    } catch (error) {
      assert(error.message.includes('revert'));
    }

    await ensJobPages.setRevertHook(3, true, { from: owner });
    await manager.createJob('ipfs://spec', web3.utils.toWei('10'), 100, 'details', { from: employer });
    await manager.applyForJob(0, '', EMPTY, EMPTY, { from: agent });
    await manager.requestJobCompletion(0, 'ipfs://completion', { from: agent });
    assert.equal((await ensJobPages.completionCalls()).toString(), '0');

    await ensJobPages.setRevertHook(3, false, { from: owner });
    await manager.syncEnsForJob(0, 3, { from: owner });
    assert.equal((await ensJobPages.completionCalls()).toString(), '1');
    assert.equal(await ensJobPages.lastCompletionURI(), 'ipfs://completion');
  });
});
