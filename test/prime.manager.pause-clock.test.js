const assert = require('assert');
const { expectRevert, time } = require('@openzeppelin/test-helpers');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const UriUtils = artifacts.require('UriUtils');
const BondMath = artifacts.require('BondMath');
const ReputationMath = artifacts.require('ReputationMath');
const ENSOwnership = artifacts.require('ENSOwnership');
const MockERC20 = artifacts.require('MockERC20');
const MockERC721 = artifacts.require('MockERC721');

const ZERO32 = `0x${'00'.repeat(32)}`;
const EMPTY = [];

contract('Prime manager pause-safe clocks', (accounts) => {
  const [owner, employer, agentA, validatorA] = accounts;
  let token;
  let manager;

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
      'ipfs://base',
      owner,
      owner,
      [ZERO32, ZERO32, ZERO32, ZERO32],
      [ZERO32, ZERO32],
      { from: owner }
    );

    const agiType = await MockERC721.new({ from: owner });
    await agiType.mint(agentA, { from: owner });
    await manager.addOrUpdateAGIType(agiType.address, 92, { from: owner });

    await manager.addAdditionalAgent(agentA, { from: owner });
    await manager.addAdditionalValidator(validatorA, { from: owner });
    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setRequiredValidatorDisapprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(15, { from: owner });
    await manager.setCompletionReviewPeriod(20, { from: owner });
    await manager.setDisputeReviewPeriod(25, { from: owner });

    const mint = web3.utils.toWei('10000');
    for (const actor of [employer, agentA, validatorA]) {
      await token.mint(actor, mint, { from: owner });
      await token.approve(manager.address, mint, { from: actor });
    }
  });

  async function createSelectedJob() {
    const payout = web3.utils.toWei('10');
    const tx = await manager.createConfiguredJob('ipfs://job/spec', payout, 180, 'details', 1, ZERO32, { from: employer });
    return tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();
  }

  it('freezes selected-agent acceptance window while paused', async () => {
    const jobId = await createSelectedJob();
    await manager.designateSelectedAgent(jobId, agentA, 20, 0, { from: owner });

    await time.increase(10);
    await manager.pause({ from: owner });
    await time.increase(25);
    await manager.unpause({ from: owner });

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });
  });

  it('freezes checkpoint deadline while settlement is paused', async () => {
    const jobId = await createSelectedJob();
    await manager.designateSelectedAgent(jobId, agentA, 20, 20, { from: owner });
    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });

    await time.increase(10);
    await manager.setSettlementPaused(true, { from: owner });
    await time.increase(20);
    await manager.setSettlementPaused(false, { from: owner });

    await manager.submitCheckpoint(jobId, 'ipfs://checkpoint/ok', { from: agentA });
  });

  it('freezes completion review and challenge windows during settlement pause', async () => {
    const jobId = await createSelectedJob();
    await manager.designateSelectedAgent(jobId, agentA, 20, 0, { from: owner });
    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });
    await manager.requestJobCompletion(jobId, 'ipfs://completion', { from: agentA });

    await time.increase(8);
    await manager.setSettlementPaused(true, { from: owner });
    await time.increase(20);
    await manager.setSettlementPaused(false, { from: owner });

    await manager.validateJob(jobId, '', EMPTY, { from: validatorA });
    await expectRevert.unspecified(manager.finalizeJob(jobId, { from: owner }));

    await time.increase(16);
    await manager.finalizeJob(jobId, { from: owner });
  });

  it('freezes stale-dispute timeout while paused', async () => {
    const jobId = await createSelectedJob();
    await manager.designateSelectedAgent(jobId, agentA, 20, 0, { from: owner });
    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });
    await manager.requestJobCompletion(jobId, 'ipfs://completion', { from: agentA });
    await manager.disputeJob(jobId, { from: employer });

    await time.increase(10);
    await manager.pause({ from: owner });
    await time.increase(30);
    await manager.unpause({ from: owner });

    await expectRevert.unspecified(manager.resolveStaleDispute(jobId, true, { from: owner }));
    await time.increase(16);
    await manager.resolveStaleDispute(jobId, true, { from: owner });
    const info = await manager.getJobSelectionInfo(jobId);
    assert.equal(info[7], '0x0000000000000000000000000000000000000000');
  });
});
