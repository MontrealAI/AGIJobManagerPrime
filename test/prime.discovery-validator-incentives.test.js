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

function scoreCommitment(procurementId, finalist, validator, score, salt) {
  return web3.utils.soliditySha3(
    { type: 'uint256', value: procurementId },
    { type: 'address', value: finalist },
    { type: 'address', value: validator },
    { type: 'uint8', value: score },
    { type: 'bytes32', value: salt }
  );
}

contract('Prime discovery validator incentives', (accounts) => {
  const [owner, employer, agentA, validatorA, validatorB, validatorC] = accounts;
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
    await manager.addOrUpdateAGIType(agiType.address, 95, { from: owner });

    await manager.addAdditionalAgent(agentA, { from: owner });
    await manager.addAdditionalValidator(validatorA, { from: owner });
    await manager.addAdditionalValidator(validatorB, { from: owner });
    await manager.addAdditionalValidator(validatorC, { from: owner });

    const mint = web3.utils.toWei('100000');
    for (const actor of [employer, agentA, validatorA, validatorB, validatorC]) {
      await token.mint(actor, mint, { from: owner });
      await token.approve(manager.address, mint, { from: actor });
      await token.approve(discovery.address, mint, { from: actor });
    }

    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });
    await manager.setPremiumReputationThreshold(0, { from: owner });
  });

  async function createSingleFinalistProcurement(opts = {}) {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://prime/incentives/job',
      payout: web3.utils.toWei('100'),
      duration: 3600,
      details: 'validator incentives'
    };

    const proc = {
      commitDeadline: now + 20,
      revealDeadline: now + 40,
      finalistAcceptDeadline: now + 60,
      trialDeadline: now + 80,
      scoreCommitDeadline: now + 100,
      scoreRevealDeadline: now + 120,
      selectedAcceptanceWindow: 50,
      checkpointWindow: 20,
      finalistCount: 1,
      minValidatorReveals: opts.minValidatorReveals || 2,
      maxValidatorRevealsPerFinalist: 3,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('2'),
      stipendPerFinalist: web3.utils.toWei('1'),
      validatorRewardPerReveal: web3.utils.toWei('1'),
      validatorScoreBond: web3.utils.toWei('0.5'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const procurementId = create.logs.find((l) => l.event === 'ProcurementCreated').args.procurementId.toNumber();

    const salt = web3.utils.soliditySha3('agent-application');
    const uri = 'ipfs://prime/incentives/application';
    const commitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'string', value: uri },
      { type: 'bytes32', value: salt }
    );

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increaseTo(proc.revealDeadline - 1);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
    await time.increaseTo(proc.revealDeadline + 1);
    await discovery.finalizeShortlist(procurementId, { from: owner });

    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://prime/incentives/trial', { from: agentA });

    return { procurementId, proc };
  }

  it('defers validator payout until winner finalization', async () => {
    const { procurementId, proc } = await createSingleFinalistProcurement();

    const salt = web3.utils.soliditySha3('score-a');
    const commitment = scoreCommitment(procurementId, agentA, validatorA, 80, salt);

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    await discovery.commitFinalistScore(procurementId, agentA, commitment, '', EMPTY, { from: validatorA });

    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 80, salt, '', EMPTY, { from: validatorA });

    assert.equal((await discovery.canClaim(validatorA)).toString(), '0', 'reveal should not immediately credit reward');

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    assert((await discovery.canClaim(validatorA)).gt(web3.utils.toBN(0)), 'validator claim should be credited at settlement');
  });

  it('rewards close scores more and slashes extreme outliers', async () => {
    const { procurementId, proc } = await createSingleFinalistProcurement();

    const entries = [
      [validatorA, 80, web3.utils.soliditySha3('score-close')],
      [validatorB, 95, web3.utils.soliditySha3('score-medium')],
      [validatorC, 10, web3.utils.soliditySha3('score-outlier')],
    ];

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    for (const [validator, score, salt] of entries) {
      await discovery.commitFinalistScore(
        procurementId,
        agentA,
        scoreCommitment(procurementId, agentA, validator, score, salt),
        '',
        EMPTY,
        { from: validator }
      );
    }

    await time.increaseTo(proc.scoreRevealDeadline - 1);
    for (const [validator, score, salt] of entries) {
      await discovery.revealFinalistScore(procurementId, agentA, score, salt, '', EMPTY, { from: validator });
    }

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    const claimClose = await discovery.canClaim(validatorA);
    const claimMid = await discovery.canClaim(validatorB);
    const claimOutlier = await discovery.canClaim(validatorC);

    assert(claimClose.gt(claimMid), 'close scorer should earn more than medium scorer');
    assert(claimMid.gt(claimOutlier), 'medium scorer should earn more than outlier scorer');
    assert(claimOutlier.lt(web3.utils.toBN(web3.utils.toWei('0.3'))), 'extreme outlier should lose bond and most rewards');
  });


  it('emits deterministic settlement bands for close/medium/extreme scores', async () => {
    const { procurementId, proc } = await createSingleFinalistProcurement();

    const entries = [
      [validatorA, 80, web3.utils.soliditySha3('band-close')],
      [validatorB, 95, web3.utils.soliditySha3('band-medium')],
      [validatorC, 10, web3.utils.soliditySha3('band-extreme')],
    ];

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    for (const [validator, score, salt] of entries) {
      await discovery.commitFinalistScore(
        procurementId,
        agentA,
        scoreCommitment(procurementId, agentA, validator, score, salt),
        '',
        EMPTY,
        { from: validator }
      );
    }

    await time.increaseTo(proc.scoreRevealDeadline - 1);
    for (const [validator, score, salt] of entries) {
      await discovery.revealFinalistScore(procurementId, agentA, score, salt, '', EMPTY, { from: validator });
    }

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    const tx = await discovery.finalizeWinner(procurementId, { from: owner });

    const settled = tx.logs.filter((log) => log.event === 'ScoreSettled');
    const byValidator = new Map(settled.map((log) => [log.args.validator.toLowerCase(), log.args]));

    assert.equal(byValidator.get(validatorA.toLowerCase()).band.toString(), '0', 'close score should map to band 0');
    assert.equal(byValidator.get(validatorB.toLowerCase()).band.toString(), '1', 'moderate deviation should map to band 1');
    assert.equal(byValidator.get(validatorC.toLowerCase()).band.toString(), '3', 'extreme outlier should map to band 3');
  });

  it('slashes non-reveal validator bonds to employer', async () => {
    const { procurementId, proc } = await createSingleFinalistProcurement({ minValidatorReveals: 1 });

    const revealSalt = web3.utils.soliditySha3('score-reveal');
    const hideSalt = web3.utils.soliditySha3('score-hide');

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    await discovery.commitFinalistScore(procurementId, agentA, scoreCommitment(procurementId, agentA, validatorA, 75, revealSalt), '', EMPTY, { from: validatorA });
    await discovery.commitFinalistScore(procurementId, agentA, scoreCommitment(procurementId, agentA, validatorB, 70, hideSalt), '', EMPTY, { from: validatorB });

    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 75, revealSalt, '', EMPTY, { from: validatorA });

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    const employerClaim = await discovery.canClaim(employer);
    assert(employerClaim.gte(web3.utils.toBN(web3.utils.toWei('0.5'))), 'employer should receive non-reveal bond slash');
  });



  it('deterministically splits equal-closeness rewards without order dependence', async () => {
    const { procurementId, proc } = await createSingleFinalistProcurement({ minValidatorReveals: 2 });

    const entries = [
      [validatorA, 78, web3.utils.soliditySha3('tie-a')],
      [validatorB, 82, web3.utils.soliditySha3('tie-b')],
    ];

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    for (const [validator, score, salt] of entries) {
      await discovery.commitFinalistScore(
        procurementId,
        agentA,
        scoreCommitment(procurementId, agentA, validator, score, salt),
        '',
        EMPTY,
        { from: validator }
      );
    }

    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 82, entries[1][2], '', EMPTY, { from: validatorB });
    await discovery.revealFinalistScore(procurementId, agentA, 78, entries[0][2], '', EMPTY, { from: validatorA });

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    const claimA = await discovery.canClaim(validatorA);
    const claimB = await discovery.canClaim(validatorB);

    assert.equal(claimA.toString(), claimB.toString(), 'equal deviations should settle equally');
  });

  it('conserves validator reward budget and leaves no validator bond stranded after finalization', async () => {
    const { procurementId, proc } = await createSingleFinalistProcurement({ minValidatorReveals: 2 });

    const entries = [
      [validatorA, 81, web3.utils.soliditySha3('budget-a')],
      [validatorB, 78, web3.utils.soliditySha3('budget-b')],
      [validatorC, 10, web3.utils.soliditySha3('budget-c')],
    ];

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    for (const [validator, score, salt] of entries) {
      await discovery.commitFinalistScore(
        procurementId,
        agentA,
        scoreCommitment(procurementId, agentA, validator, score, salt),
        '',
        EMPTY,
        { from: validator }
      );
    }

    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 81, entries[0][2], '', EMPTY, { from: validatorA });
    await discovery.revealFinalistScore(procurementId, agentA, 78, entries[1][2], '', EMPTY, { from: validatorB });

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    const rewardCap = web3.utils.toBN(proc.validatorRewardPerReveal).mul(web3.utils.toBN('3'));
    const finalA = await discovery.scoreCommits(procurementId, agentA, validatorA);
    const finalB = await discovery.scoreCommits(procurementId, agentA, validatorB);
    const finalC = await discovery.scoreCommits(procurementId, agentA, validatorC);

    const vA = await discovery.canClaim(validatorA);
    const vB = await discovery.canClaim(validatorB);
    const vC = await discovery.canClaim(validatorC);
    const emp = await discovery.canClaim(employer);

    const totalValidatorRewards = vA.add(vB).add(vC).sub(web3.utils.toBN(proc.validatorScoreBond).mul(web3.utils.toBN('2')));
    assert(totalValidatorRewards.lte(rewardCap), 'total validator rewards must stay under prefunded cap');
    assert.equal(finalA.bond.toString(), '0', 'revealed validator A bond should be settled');
    assert.equal(finalB.bond.toString(), '0', 'revealed validator B bond should be settled');
    assert.equal(finalC.bond.toString(), '0', 'non-revealed validator C bond should be slashed/settled');
    assert(emp.gt(web3.utils.toBN('0')), 'employer should receive slashes and unused reward budget');
  });

  it('under quorum only pays liveness component and refunds quality budget', async () => {
    const { procurementId, proc } = await createSingleFinalistProcurement({ minValidatorReveals: 3 });

    const salt = web3.utils.soliditySha3('score-underquorum');
    await time.increaseTo(proc.scoreCommitDeadline - 1);
    await discovery.commitFinalistScore(procurementId, agentA, scoreCommitment(procurementId, agentA, validatorA, 88, salt), '', EMPTY, { from: validatorA });

    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 88, salt, '', EMPTY, { from: validatorA });

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    const validatorClaim = await discovery.canClaim(validatorA);
    const expected = web3.utils.toBN(web3.utils.toWei('0.6')); // 0.5 bond + 10% of 1.0 reward unit
    assert.equal(validatorClaim.toString(), expected.toString(), 'under-quorum reveal should only receive bond + liveness share');
  });
});
