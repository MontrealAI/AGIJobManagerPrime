const { expectRevert, time } = require('@openzeppelin/test-helpers');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const UriUtils = artifacts.require('UriUtils');
const BondMath = artifacts.require('BondMath');
const ReputationMath = artifacts.require('ReputationMath');
const ENSOwnership = artifacts.require('ENSOwnership');
const MockERC20 = artifacts.require('MockERC20');
const MockERC721 = artifacts.require('MockERC721');

const ZERO32 = `0x${'00'.repeat(32)}`;

contract('Prime manager pause-safe clocks', (accounts) => {
  const [owner, employer, agent, validator] = accounts;
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

    await manager.addAdditionalAgent(agent, { from: owner });
    await manager.addAdditionalValidator(validator, { from: owner });
    await manager.setRequiredValidatorApprovals(1, { from: owner });

    const agiType = await MockERC721.new({ from: owner });
    await agiType.mint(agent, { from: owner });
    await manager.addOrUpdateAGIType(agiType.address, 90, { from: owner });

    const mint = web3.utils.toWei('500');
    for (const actor of [employer, agent, validator]) {
      await token.mint(actor, mint, { from: owner });
      await token.approve(manager.address, mint, { from: actor });
    }
  });

  async function createSelectedJob(window = 30, checkpoint = 20) {
    const tx = await manager.createConfiguredJob(
      'ipfs://job/spec',
      web3.utils.toWei('10'),
      200,
      'details',
      1,
      ZERO32,
      { from: employer }
    );
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();
    await manager.designateSelectedAgent(jobId, agent, window, checkpoint, { from: owner });
    return jobId;
  }

  it('freezes selected-agent acceptance clock across emergency pause', async () => {
    const jobId = await createSelectedJob(30, 0);

    await time.increase(15);
    await manager.pause({ from: owner });
    await time.increase(40);
    await expectRevert.unspecified(manager.applyForJob(jobId, '', [], [], { from: agent }));

    await manager.unpause({ from: owner });
    await manager.applyForJob(jobId, '', [], [], { from: agent });
  });

  it('freezes checkpoint default window across settlement pause', async () => {
    const jobId = await createSelectedJob(60, 25);
    await manager.applyForJob(jobId, '', [], [], { from: agent });

    await time.increase(15);
    await manager.setSettlementPaused(true, { from: owner });
    await time.increase(30);
    await expectRevert.unspecified(manager.submitCheckpoint(jobId, 'ipfs://cp', { from: agent }));

    await manager.setSettlementPaused(false, { from: owner });
    await manager.submitCheckpoint(jobId, 'ipfs://cp', { from: agent });
  });

  it('preserves challenge window fairness when approval happens after a prior pause epoch', async () => {
    const jobId = await createSelectedJob(60, 0);
    await manager.setChallengePeriodAfterApproval(100, { from: owner });

    await manager.applyForJob(jobId, '', [], [], { from: agent });
    await manager.requestJobCompletion(jobId, 'ipfs://done', { from: agent });

    await manager.setSettlementPaused(true, { from: owner });
    await time.increase(500);
    await manager.setSettlementPaused(false, { from: owner });

    await manager.validateJob(jobId, '', [], { from: validator });

    await time.increase(80);
    await expectRevert.unspecified(manager.finalizeJob(jobId, { from: employer }));

    await time.increase(30);
    await manager.finalizeJob(jobId, { from: employer });

    await expectRevert.unspecified(manager.finalizeJob(jobId, { from: employer }));
  });

  it('preserves stale-dispute timeout fairness for auto-open disputes after prior pause epochs', async () => {
    const jobId = await createSelectedJob(60, 0);
    await manager.setRequiredValidatorDisapprovals(1, { from: owner });
    await manager.setDisputeReviewPeriod(100, { from: owner });

    await manager.applyForJob(jobId, '', [], [], { from: agent });
    await manager.requestJobCompletion(jobId, 'ipfs://done', { from: agent });

    await manager.setSettlementPaused(true, { from: owner });
    await time.increase(400);
    await manager.setSettlementPaused(false, { from: owner });

    await manager.disapproveJob(jobId, '', [], { from: validator });

    await time.increase(90);
    await expectRevert.unspecified(manager.resolveStaleDispute(jobId, true, { from: owner }));

    await time.increase(20);
    await manager.resolveStaleDispute(jobId, true, { from: owner });

    await expectRevert.unspecified(manager.finalizeJob(jobId, { from: employer }));
  });

});
