const assert = require('assert');
const { expectRevert, time } = require('@openzeppelin/test-helpers');
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
const EMPTY = [];

function appCommitment(procurementId, agent, uri, salt) {
  return web3.utils.soliditySha3(
    { type: 'uint256', value: procurementId },
    { type: 'address', value: agent },
    { type: 'string', value: uri },
    { type: 'bytes32', value: salt }
  );
}

function scoreCommitment(procurementId, finalist, validator, score, salt) {
  return web3.utils.soliditySha3(
    { type: 'uint256', value: procurementId },
    { type: 'address', value: finalist },
    { type: 'address', value: validator },
    { type: 'uint8', value: score },
    { type: 'bytes32', value: salt }
  );
}

contract('Prime discovery pause-safe clocks', (accounts) => {
  const [owner, employer, agentA, validatorA, outsider] = accounts;
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
    await manager.addOrUpdateAGIType(agiType.address, 92, { from: owner });

    await manager.addAdditionalAgent(agentA, { from: owner });
    await manager.addAdditionalValidator(validatorA, { from: owner });
    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });
    await manager.setPremiumReputationThreshold(0, { from: owner });

    const mint = web3.utils.toWei('10000');
    for (const actor of [employer, agentA, validatorA]) {
      await token.mint(actor, mint, { from: owner });
      await token.approve(manager.address, mint, { from: actor });
      await token.approve(discovery.address, mint, { from: actor });
    }
  });

  async function createProcurement() {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/pause-clock/spec',
      payout: web3.utils.toWei('10'),
      duration: 3600,
      details: 'pause-safe windows'
    };

    const proc = {
      commitDeadline: now + 20,
      revealDeadline: now + 40,
      finalistAcceptDeadline: now + 60,
      trialDeadline: now + 80,
      scoreCommitDeadline: now + 100,
      scoreRevealDeadline: now + 120,
      selectedAcceptanceWindow: 60,
      checkpointWindow: 60,
      finalistCount: 1,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 1,
      historicalWeightBps: 3000,
      trialWeightBps: 7000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('2'),
      stipendPerFinalist: web3.utils.toWei('1'),
      validatorRewardPerReveal: web3.utils.toWei('0.1'),
      validatorScoreBond: web3.utils.toWei('0.5')
    };

    const tx = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    return tx.logs.find((l) => l.event === 'ProcurementCreated').args.procurementId.toNumber();
  }

  async function progressToShortlisted(procurementId) {
    const salt = web3.utils.randomHex(32);
    const uri = 'ipfs://app/agentA';
    const commitment = appCommitment(procurementId, agentA, uri, salt);

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increase(21);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
    await time.increase(20);
    await discovery.finalizeShortlist(procurementId, { from: owner });
  }

  async function progressToAcceptedTrial(procurementId) {
    await progressToShortlisted(procurementId);
    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://trial/A', { from: agentA });
  }

  it('freezes finalist acceptance window while discovery is paused', async () => {
    const procurementId = await createProcurement();
    await progressToShortlisted(procurementId);

    await time.increase(15);
    await discovery.pause({ from: owner });
    await time.increase(40);
    await expectRevert.unspecified(discovery.acceptFinalist(procurementId, { from: agentA }));
    await discovery.unpause({ from: owner });

    await discovery.acceptFinalist(procurementId, { from: agentA });
  });

  it('freezes trial and validator reveal windows across repeated pause cycles', async () => {
    const procurementId = await createProcurement();
    await progressToAcceptedTrial(procurementId);

    await time.increase(10);
    await discovery.pause({ from: owner });
    await time.increase(10);
    await discovery.unpause({ from: owner });
    await discovery.pause({ from: owner });
    await time.increase(15);
    await discovery.unpause({ from: owner });

    await time.increase(45);
    const scoreSalt = web3.utils.randomHex(32);
    const commit = scoreCommitment(procurementId, agentA, validatorA, 91, scoreSalt);
    await discovery.commitFinalistScore(procurementId, agentA, commit, '', EMPTY, { from: validatorA });

    await discovery.pause({ from: owner });
    await time.increase(30);
    await discovery.unpause({ from: owner });
    await time.increase(20);

    await discovery.revealFinalistScore(procurementId, agentA, 91, scoreSalt, '', EMPTY, { from: validatorA });
  });

  it('keeps winner finalization available for neutral closeout under settlement freeze when no winner is designatable', async () => {
    const procurementId = await createProcurement();
    await progressToShortlisted(procurementId);

    await time.increase(95);
    await manager.setSettlementPaused(true, { from: owner });

    assert.equal(await discovery.isWinnerFinalizable(procurementId), true, 'neutral closeout should stay finalizable');
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'FW');

    const tx = await discovery.finalizeWinner(procurementId, { from: outsider });
    assert(tx.logs.find((l) => l.event === 'ProcurementClosedWithoutWinner'));
  });

  it('surfaces linked manager pause states only when winner assignment would be required', async () => {
    const procurementId = await createProcurement();
    await progressToAcceptedTrial(procurementId);

    await time.increase(45);
    const scoreSalt = web3.utils.randomHex(32);
    const commit = scoreCommitment(procurementId, agentA, validatorA, 90, scoreSalt);
    await discovery.commitFinalistScore(procurementId, agentA, commit, '', EMPTY, { from: validatorA });
    await time.increase(20);
    await discovery.revealFinalistScore(procurementId, agentA, 90, scoreSalt, '', EMPTY, { from: validatorA });
    await time.increase(21);

    await manager.pause({ from: owner });
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'LMP');
    assert.equal(await discovery.isWinnerFinalizable(procurementId), false);

    await manager.unpause({ from: owner });
    await manager.setSettlementPaused(true, { from: owner });
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'LSF');
    assert.equal(await discovery.isWinnerFinalizable(procurementId), false);
  });

  it('allows in-flight procurements to continue during intake pause while preserving helper truthfulness', async () => {
    const procurementId = await createProcurement();
    const salt = web3.utils.randomHex(32);
    const uri = 'ipfs://app/agentA/intake';
    const commitment = appCommitment(procurementId, agentA, uri, salt);

    await discovery.setIntakePaused(true, { from: owner });
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'WC');

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increase(21);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
  });

  it('keeps effective deadlines anchored for procurements created after prior pause epochs', async () => {
    await discovery.pause({ from: owner });
    await time.increase(25);
    await discovery.unpause({ from: owner });

    const procurementId = await createProcurement();
    await time.increase(21);
    const salt = web3.utils.randomHex(32);
    const uri = 'ipfs://app/agentA/post-pause';
    const commitment = appCommitment(procurementId, agentA, uri, salt);

    await expectCustomError(
      discovery.commitApplication.call(procurementId, commitment, '', EMPTY, { from: agentA }),
      'InvalidState'
    );
  });
});
