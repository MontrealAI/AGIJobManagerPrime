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
    assert.equal((await ensJobPages.createCalls()).toString(), '1');
    assert.equal((await ensJobPages.lastHook()).toString(), '1');

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agent });
    assert.equal((await ensJobPages.assignCalls()).toString(), '1');
    assert.equal((await ensJobPages.lastHook()).toString(), '2');

    await manager.requestJobCompletion(jobId, 'ipfs://completion', { from: agent });
    assert.equal((await ensJobPages.completionCalls()).toString(), '1');
    assert.equal((await ensJobPages.lastHook()).toString(), '3');

    await manager.validateJob(jobId, '', EMPTY, { from: validator });
    await time.increase(2);
    const finalizeTx = await manager.finalizeJob(jobId, { from: employer });
    const issued = finalizeTx.logs.find((log) => log.event === 'NFTIssued');
    assert.ok(issued.args.tokenURI.includes('ipfs://completion'));
  });

  it('keeps settlement non-blocking when ENS completion hook reverts', async () => {
    const incompatible = await MockNoSupportsInterface.new({ from: owner });
    await manager.setEnsJobPages(incompatible.address, { from: owner });
    assert.equal(await manager.ensJobPages(), incompatible.address);

    await manager.setEnsJobPages(ensJobPages.address, { from: owner });

    await ensJobPages.setRevertHook(3, true, { from: owner });
    const payout = web3.utils.toWei('10');
    await manager.createJob('ipfs://spec', payout, 100, 'details', { from: employer });
    await manager.applyForJob(0, '', EMPTY, EMPTY, { from: agent });
    await manager.requestJobCompletion(0, 'ipfs://completion', { from: agent });
    assert.equal((await ensJobPages.completionCalls()).toString(), '0');
  });
});
