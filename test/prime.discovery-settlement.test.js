const assert = require('assert');
const { time } = require('@openzeppelin/test-helpers');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const AGIJobDiscoveryPrime = artifacts.require('AGIJobDiscoveryPrime');
const UriUtils = artifacts.require('UriUtils');
const BondMath = artifacts.require('BondMath');
const ReputationMath = artifacts.require('ReputationMath');
const ENSOwnership = artifacts.require('ENSOwnership');
const MockERC20 = artifacts.require('MockERC20');
const MockERC721 = artifacts.require('MockERC721');

const ZERO32 = `0x${'00'.repeat(32)}`;
const EMPTY = [];

function leafFor(addr) {
  return web3.utils.soliditySha3({ type: 'address', value: addr });
}

contract('Prime discovery + settlement', (accounts) => {
  const [owner, employer, agentA, agentB, validatorA, validatorB] = accounts;
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
    await agiType.mint(agentA, { from: owner });
    await agiType.mint(agentB, { from: owner });
    await manager.addOrUpdateAGIType(agiType.address, 92, { from: owner });

    await manager.addAdditionalAgent(agentA, { from: owner });
    await manager.addAdditionalAgent(agentB, { from: owner });
    await manager.addAdditionalValidator(validatorA, { from: owner });
    await manager.addAdditionalValidator(validatorB, { from: owner });

    const mint = web3.utils.toWei('100000');
    for (const actor of [employer, agentA, agentB, validatorA, validatorB]) {
      await token.mint(actor, mint, { from: owner });
      await token.approve(manager.address, mint, { from: actor });
      await token.approve(discovery.address, mint, { from: actor });
    }

    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });
    await manager.setPremiumReputationThreshold(0, { from: owner });
  });


  it('rejects zero-address discovery module wiring', async () => {
    try {
      await manager.setDiscoveryModule('0x0000000000000000000000000000000000000000', { from: owner });
      assert.fail('expected revert');
    } catch (error) {
      assert(String(error.message).includes('InvalidParameters'), `unexpected error: ${error.message}`);
    }
  });

  it('supports ordinary open-first-come settlement flow', async () => {
    const payout = web3.utils.toWei('100');
    const tx = await manager.createJob('ipfs://job/open', payout, 3600, 'open flow', { from: employer });
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });
    await manager.requestJobCompletion(jobId, 'ipfs://job/open/deliverable', { from: agentA });
    await manager.validateJob(jobId, '', EMPTY, { from: validatorA });
    await time.increase(2);
    await manager.finalizeJob(jobId, { from: employer });

    const info = await manager.getJobSelectionInfo(jobId);
    assert.equal(info[7], agentA, 'assigned agent should be retained after finalization');
    const rep = await manager.reputation(agentA);
    assert(rep.toNumber() > 0, 'reputation should increase after successful settlement');
  });

  it('supports per-job merkle intake and employer refund expiry path', async () => {
    const payout = web3.utils.toWei('40');
    const create = await manager.createConfiguredJob('ipfs://job/root', payout, 3600, 'per job root', 2, ZERO32, { from: employer });
    const jobId = create.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();

    const root = leafFor(agentA);
    await manager.setPerJobAgentRoot(jobId, root, 50, { from: owner });
    await manager.applyForJob(jobId, '', EMPTY, [], { from: agentA });

    await time.increase(3700);
    const before = await token.balanceOf(employer);
    await manager.expireJob(jobId, { from: owner });
    const after = await token.balanceOf(employer);

    assert(after.gt(before), 'employer should recover escrow after expiry');
  });

  it('runs procurement commit/reveal, shortlist, finalist trials, validator score commit/reveal and winner handoff with fallback promotion', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium',
      payout: web3.utils.toWei('50'),
      duration: 3600,
      details: 'premium flow',
    };
    const proc = {
      commitDeadline: now + 10,
      revealDeadline: now + 20,
      finalistAcceptDeadline: now + 30,
      trialDeadline: now + 40,
      scoreCommitDeadline: now + 50,
      scoreRevealDeadline: now + 60,
      selectedAcceptanceWindow: 5,
      checkpointWindow: 0,
      finalistCount: 2,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 2,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('2'),
      stipendPerFinalist: web3.utils.toWei('1'),
      validatorRewardPerReveal: web3.utils.toWei('0.5'),
      validatorScoreBond: web3.utils.toWei('0.2'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const premiumEvent = create.logs.find((l) => l.event === 'PremiumJobCreated');
    const procurementId = premiumEvent.args.procurementId.toNumber();
    const jobId = premiumEvent.args.jobId.toNumber();

    const saltA = web3.utils.soliditySha3('A');
    const saltB = web3.utils.soliditySha3('B');
    const uriA = 'ipfs://application/A';
    const uriB = 'ipfs://application/B';
    const cA = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'string', value: uriA },
      { type: 'bytes32', value: saltA }
    );
    const cB = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentB },
      { type: 'string', value: uriB },
      { type: 'bytes32', value: saltB }
    );

    await discovery.commitApplication(procurementId, cA, { from: agentA });
    await discovery.commitApplication(procurementId, cB, { from: agentB });
    await time.increaseTo(proc.revealDeadline - 5);
    await discovery.revealApplication(procurementId, '', EMPTY, saltA, uriA, { from: agentA });
    await discovery.revealApplication(procurementId, '', EMPTY, saltB, uriB, { from: agentB });

    await time.increaseTo(proc.revealDeadline + 1);
    await discovery.finalizeShortlist(procurementId, { from: owner });

    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.acceptFinalist(procurementId, { from: agentB });
    await discovery.submitTrial(procurementId, 'ipfs://trial/A', { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://trial/B', { from: agentB });

    await time.increaseTo(proc.scoreCommitDeadline - 2);
    const scoreSaltA = web3.utils.soliditySha3('scoreA');
    const scoreSaltB = web3.utils.soliditySha3('scoreB');
    const commitA = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'address', value: validatorA },
      { type: 'uint8', value: 95 },
      { type: 'bytes32', value: scoreSaltA }
    );
    const commitB = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentB },
      { type: 'address', value: validatorB },
      { type: 'uint8', value: 80 },
      { type: 'bytes32', value: scoreSaltB }
    );

    await discovery.commitFinalistScore(procurementId, agentA, commitA, '', EMPTY, { from: validatorA });
    await discovery.commitFinalistScore(procurementId, agentB, commitB, '', EMPTY, { from: validatorB });

    await time.increaseTo(proc.scoreRevealDeadline - 2);
    await discovery.revealFinalistScore(procurementId, agentA, 95, scoreSaltA, '', EMPTY, { from: validatorA });
    await discovery.revealFinalistScore(procurementId, agentB, 80, scoreSaltB, '', EMPTY, { from: validatorB });

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    let info = await manager.getJobSelectionInfo(jobId);
    assert.equal(info[1], agentA, 'winner should be designated as selected agent');

    await time.increase(6);
    await discovery.promoteFallbackFinalist(procurementId, { from: employer });

    info = await manager.getJobSelectionInfo(jobId);
    assert.equal(info[1], agentB, 'fallback finalist should be promoted after timeout');

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentB });
    await manager.requestJobCompletion(jobId, 'ipfs://job/premium/final', { from: agentB });
    await manager.validateJob(jobId, '', EMPTY, { from: validatorA });
    await time.increase(2);
    await manager.finalizeJob(jobId, { from: employer });
  });
});
