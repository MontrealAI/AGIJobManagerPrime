const assert = require('assert');
const { expectRevert } = require('@openzeppelin/test-helpers');
const { expectCustomError } = require('./helpers/errors');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const AGIJobDiscoveryPrime = artifacts.require('AGIJobDiscoveryPrime');
const UriUtils = artifacts.require('UriUtils');
const BondMath = artifacts.require('BondMath');
const ReputationMath = artifacts.require('ReputationMath');
const ENSOwnership = artifacts.require('ENSOwnership');
const MockERC20 = artifacts.require('MockERC20');
const MockERC721 = artifacts.require('MockERC721');

const ZERO32 = `0x${'00'.repeat(32)}`;

contract('Prime ownership + graceful pause model', (accounts) => {
  const [owner, finalOwner, employer, agent, validator, outsider, multisigLike] = accounts;
  let token;
  let manager;
  let discovery;

  before(async () => {
    const uriUtils = await UriUtils.new({ from: owner });
    const bondMath = await BondMath.new({ from: owner });
    const reputationMath = await ReputationMath.new({ from: owner });
    const ensOwnership = await ENSOwnership.new({ from: owner });

    AGIJobManagerPrime.link('UriUtils', uriUtils.address);
    AGIJobManagerPrime.link('BondMath', bondMath.address);
    AGIJobManagerPrime.link('ReputationMath', reputationMath.address);
    AGIJobManagerPrime.link('ENSOwnership', ensOwnership.address);
    AGIJobDiscoveryPrime.link('UriUtils', uriUtils.address);
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

    discovery = await AGIJobDiscoveryPrime.new(manager.address, { from: owner });
    await manager.setDiscoveryModule(discovery.address, { from: owner });

    const agiType = await MockERC721.new({ from: owner });
    await agiType.mint(agent, { from: owner });
    await manager.addOrUpdateAGIType(agiType.address, 90, { from: owner });

    await manager.addAdditionalAgent(agent, { from: owner });
    await manager.addAdditionalValidator(validator, { from: owner });
    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });

    const mint = web3.utils.toWei('500');
    for (const actor of [employer, agent, validator]) {
      await token.mint(actor, mint, { from: owner });
      await token.approve(manager.address, mint, { from: actor });
      await token.approve(discovery.address, mint, { from: actor });
    }
  });

  it('uses one-step manager transfer and two-step discovery transfer', async () => {
    await manager.transferOwnership(multisigLike, { from: owner });
    assert.equal(await manager.owner(), multisigLike);

    await discovery.transferOwnership(finalOwner, { from: owner });
    await expectCustomError(discovery.acceptOwnership.call({ from: outsider }), 'NotPendingOwner');
    await discovery.cancelOwnershipTransfer({ from: owner });
    await discovery.transferOwnership(finalOwner, { from: owner });
    await discovery.acceptOwnership({ from: finalOwner });
    assert.equal(await discovery.owner(), finalOwner);
  });

  it('keeps renounce disabled', async () => {
    await expectCustomError(manager.renounceOwnership.call({ from: owner }), 'RenounceOwnershipDisabled');
    await expectCustomError(discovery.renounceOwnership.call({ from: owner }), 'RenounceOwnershipDisabled');
  });

  it('intake pause blocks new exposure but allows already-started manager progress', async () => {
    const payout = web3.utils.toWei('10');
    const tx = await manager.createJob('ipfs://job/spec', payout, 3600, 'details', { from: employer });
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();
    await manager.applyForJob(jobId, '', [], [], { from: agent });

    await manager.pause({ from: owner });
    await expectRevert.unspecified(manager.createJob('ipfs://new', payout, 60, 'new', { from: employer }));
    await expectRevert.unspecified(manager.applyForJob(jobId, '', [], [], { from: outsider }));

    await manager.requestJobCompletion(jobId, 'ipfs://completion', { from: agent });
    await manager.validateJob(jobId, '', [], { from: validator });
  });

  it('settlement freeze blocks manager value-moving settlement while keeping dispute opening live', async () => {
    const payout = web3.utils.toWei('12');
    const tx = await manager.createJob('ipfs://job/spec2', payout, 3600, 'details', { from: employer });
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();
    await manager.applyForJob(jobId, '', [], [], { from: agent });
    await manager.requestJobCompletion(jobId, 'ipfs://completion2', { from: agent });

    await manager.setSettlementPaused(true, { from: owner });
    await manager.disputeJob(jobId, { from: employer });
    await expectCustomError(manager.finalizeJob.call(jobId, { from: employer }), 'SettlementPaused');
    await expectCustomError(manager.resolveStaleDispute.call(jobId, true, { from: owner }), 'SettlementPaused');
  });

  it('discovery intake pause blocks new procurement entry while claim path stays live', async () => {
    const intakeTx = await discovery.setIntakePaused(true, { from: owner });
    assert(intakeTx.logs.find((l) => l.event === 'IntakePauseSet'));
    await expectCustomError(
      discovery.commitApplication.call(0, web3.utils.soliditySha3('x'), '', [], { from: agent }),
      'InvalidState'
    );

    const before = await token.balanceOf(employer);
    const claimable = await discovery.canClaim(employer);
    const after = await token.balanceOf(employer);
    assert.equal(claimable.toString(), '0', 'claim view stays available during intake pause');
    assert.equal(after.toString(), before.toString(), 'intake pause does not mutate balances');
  });
});
