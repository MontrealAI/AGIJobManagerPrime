const assert = require('assert');
const { time, expectRevert } = require('@openzeppelin/test-helpers');
const { expectCustomError } = require('./helpers/errors');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const AGIJobDiscoveryPrime = artifacts.require('AGIJobDiscoveryPrime');
const UriUtils = artifacts.require('UriUtils');
const BondMath = artifacts.require('BondMath');
const ReputationMath = artifacts.require('ReputationMath');
const ENSOwnership = artifacts.require('ENSOwnership');
const MockERC20 = artifacts.require('MockERC20');
const MockERC721 = artifacts.require('MockERC721');
const MockENSJobPages = artifacts.require('MockENSJobPages');

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

    ensJobPages = await MockENSJobPages.new({ from: owner });
    await manager.setEnsJobPages(ensJobPages.address, { from: owner });

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
    await expectRevert.unspecified(
      manager.setDiscoveryModule('0x0000000000000000000000000000000000000000', { from: owner })
    );
  });

  it('rejects non-contract discovery module wiring', async () => {
    await expectRevert.unspecified(
      manager.setDiscoveryModule(agentA, { from: owner })
    );
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

  it('disables renounceOwnership to preserve business operator control', async () => {
    await expectCustomError(manager.renounceOwnership.call({ from: owner }), 'RenounceOwnershipDisabled');
  });

  it('blocks repeated dispute opening and keeps dispute bond accounting stable', async () => {
    const payout = web3.utils.toWei('22');
    const tx = await manager.createJob('ipfs://job/dispute', payout, 3600, 'dispute flow', { from: employer });
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });
    await manager.requestJobCompletion(jobId, 'ipfs://job/dispute/completion', { from: agentA });

    const before = await manager.lockedDisputeBonds();
    await manager.disputeJob(jobId, { from: employer });
    const afterFirst = await manager.lockedDisputeBonds();

    await expectCustomError(manager.disputeJob.call(jobId, { from: employer }), 'DisputeAlreadyOpen');
    const afterSecondAttempt = await manager.lockedDisputeBonds();

    assert(afterFirst.gt(before), 'initial dispute should lock a dispute bond');
    assert.equal(
      afterSecondAttempt.toString(),
      afterFirst.toString(),
      'second dispute attempt must not alter locked dispute bond accounting'
    );
  });

  it('freezes completion/dispute/challenge periods at assignment for live-job rule stability', async () => {
    const payout = web3.utils.toWei('18');
    const tx = await manager.createJob('ipfs://job/frozen-periods', payout, 3600, 'frozen periods', { from: employer });
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();

    await manager.setCompletionReviewPeriod(7 * 24 * 3600, { from: owner });
    await manager.setDisputeReviewPeriod(7 * 24 * 3600, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });

    await manager.setCompletionReviewPeriod(10, { from: owner });
    await manager.setDisputeReviewPeriod(10, { from: owner });
    await manager.setChallengePeriodAfterApproval(10, { from: owner });

    await manager.requestJobCompletion(jobId, 'ipfs://job/frozen-periods/completion', { from: agentA });
    await time.increase(12);

    await manager.validateJob(jobId, '', EMPTY, { from: validatorA });
    await expectCustomError(manager.finalizeJob.call(jobId, { from: employer }), 'InvalidState');
    await manager.disputeJob(jobId, { from: employer });
    await expectCustomError(manager.resolveStaleDispute.call(jobId, true, { from: owner }), 'InvalidState');
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





  it('supports selected-agent checkpoint timeout handling', async () => {
    const payout = web3.utils.toWei('25');
    const tx = await manager.createConfiguredJob('ipfs://job/checkpoint', payout, 120, 'checkpoint flow', 1, ZERO32, { from: employer });
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();
    await manager.designateSelectedAgent(jobId, agentA, 200, 20, { from: owner });
    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });

    await time.increase(25);
    await manager.failCheckpoint(jobId, { from: employer });

    const jobInfo = await manager.getJobSelectionInfo(jobId);
    assert.equal(jobInfo[7], agentA, 'assigned agent remains discoverable after checkpoint failure settlement');
  });

  it('keeps ENS hooks best-effort and exposes autonomy helpers', async () => {
    const payout = web3.utils.toWei('30');
    const tx = await manager.createJob('ipfs://job/ens', payout, 100, 'ens hooks', { from: employer });
    const jobId = tx.logs.find((l) => l.event === 'JobCreated').args.jobId.toNumber();

    assert.equal((await ensJobPages.createCalls()).toString(), '1', 'create hook should fire');

    await ensJobPages.setRevertHook(2, true, { from: owner });
    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentA });

    assert.equal((await ensJobPages.assignCalls()).toString(), '0', 'reverting assign hook should not brick apply');

    await manager.requestJobCompletion(jobId, 'ipfs://job/ens/completion', { from: agentA });
    await time.increase(8 * 24 * 3600);

    await manager.finalizeJob(jobId, { from: employer });

    assert.equal((await ensJobPages.lockCalls()).toString(), '1', 'lock hook should run on terminal completion');
  });


  it('reports fallback not promotable when all remaining finalists have zero composite score', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium-zero',
      payout: web3.utils.toWei('20'),
      duration: 3600,
      details: 'zero score flow',
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
      maxValidatorRevealsPerFinalist: 1,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('1'),
      stipendPerFinalist: web3.utils.toWei('0.5'),
      validatorRewardPerReveal: web3.utils.toWei('0.2'),
      validatorScoreBond: web3.utils.toWei('0.1'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const premiumEvent = create.logs.find((l) => l.event === 'PremiumJobCreated');
    const procurementId = premiumEvent.args.procurementId.toNumber();

    const salt = web3.utils.soliditySha3('Z');
    const uri = 'ipfs://application/Z';
    const commitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'string', value: uri },
      { type: 'bytes32', value: salt }
    );

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increaseTo(proc.revealDeadline - 2);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
    await time.increaseTo(proc.revealDeadline + 1);
    await discovery.finalizeShortlist(procurementId, { from: owner });

    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://trial/Z', { from: agentA });

    const scoreSalt = web3.utils.soliditySha3('scoreZ');
    const scoreCommitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'address', value: validatorA },
      { type: 'uint8', value: 0 },
      { type: 'bytes32', value: scoreSalt }
    );

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    await discovery.commitFinalistScore(procurementId, agentA, scoreCommitment, '', EMPTY, { from: validatorA });
    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 0, scoreSalt, '', EMPTY, { from: validatorA });

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    assert.equal(await discovery.isWinnerFinalizable(procurementId), true, 'winner should be finalizable after reveal window');
    await manager.pause({ from: owner });
    assert.equal(await discovery.isWinnerFinalizable(procurementId), false, 'manager pause should suppress winner finalizable helper');
    await manager.unpause({ from: owner });
    await manager.setSettlementPaused(true, { from: owner });
    assert.equal(
      await discovery.isWinnerFinalizable(procurementId),
      true,
      'settlement pause should still allow finalization when no winner is designatable'
    );
    await manager.setSettlementPaused(false, { from: owner });
    await discovery.pause({ from: owner });
    assert.equal(await discovery.isWinnerFinalizable(procurementId), false, 'paused discovery should suppress winner finalizable helper');
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'paused');
    await discovery.unpause({ from: owner });
    await discovery.finalizeWinner(procurementId, { from: owner });

    assert.equal(await discovery.isFallbackPromotable(procurementId), false, 'zero-score finalists should not appear promotable');
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'no_promotable_fallback');
  });

  it('supports permissionless staged progression through advanceProcurement', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium-advance',
      payout: web3.utils.toWei('30'),
      duration: 3600,
      details: 'advance helper flow',
    };
    const proc = {
      commitDeadline: now + 10,
      revealDeadline: now + 20,
      finalistAcceptDeadline: now + 30,
      trialDeadline: now + 40,
      scoreCommitDeadline: now + 50,
      scoreRevealDeadline: now + 60,
      selectedAcceptanceWindow: 3,
      checkpointWindow: 0,
      finalistCount: 2,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 2,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('1'),
      stipendPerFinalist: web3.utils.toWei('0.5'),
      validatorRewardPerReveal: web3.utils.toWei('0.2'),
      validatorScoreBond: web3.utils.toWei('0.1'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const premiumEvent = create.logs.find((l) => l.event === 'PremiumJobCreated');
    const procurementId = premiumEvent.args.procurementId.toNumber();
    const jobId = premiumEvent.args.jobId.toNumber();

    const saltA = web3.utils.soliditySha3('advanceA');
    const saltB = web3.utils.soliditySha3('advanceB');
    const uriA = 'ipfs://application/advance/A';
    const uriB = 'ipfs://application/advance/B';
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

    await discovery.commitApplication(procurementId, cA, '', EMPTY, { from: agentA });
    await discovery.commitApplication(procurementId, cB, '', EMPTY, { from: agentB });

    await expectRevert.unspecified(discovery.advanceProcurement(procurementId, { from: employer }));

    await time.increaseTo(proc.revealDeadline - 2);
    await discovery.revealApplication(procurementId, '', EMPTY, saltA, uriA, { from: agentA });
    await discovery.revealApplication(procurementId, '', EMPTY, saltB, uriB, { from: agentB });
    await time.increaseTo(proc.revealDeadline + 1);
    const shortlistTx = await discovery.advanceProcurement(procurementId, { from: validatorA });
    const shortlisted = shortlistTx.logs.find((l) => l.event === 'ShortlistFinalized').args.finalists;
    const firstFinalist = shortlisted[0];
    const fallbackAgent = firstFinalist.toLowerCase() === agentA.toLowerCase() ? agentB : agentA;

    await discovery.acceptFinalist(procurementId, { from: firstFinalist });
    await discovery.acceptFinalist(procurementId, { from: fallbackAgent });
    await discovery.submitTrial(procurementId, 'ipfs://trial/advance/first', { from: firstFinalist });
    await discovery.submitTrial(procurementId, 'ipfs://trial/advance/fallback', { from: fallbackAgent });

    const scoreSalt = web3.utils.soliditySha3('advance-score-a');
    const scoreCommitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: firstFinalist },
      { type: 'address', value: validatorA },
      { type: 'uint8', value: 88 },
      { type: 'bytes32', value: scoreSalt }
    );

    const fallbackScoreSalt = web3.utils.soliditySha3('advance-score-b');
    const fallbackScoreCommitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: fallbackAgent },
      { type: 'address', value: validatorB },
      { type: 'uint8', value: 77 },
      { type: 'bytes32', value: fallbackScoreSalt }
    );

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    await discovery.commitFinalistScore(procurementId, firstFinalist, scoreCommitment, '', EMPTY, { from: validatorA });
    await discovery.commitFinalistScore(procurementId, fallbackAgent, fallbackScoreCommitment, '', EMPTY, { from: validatorB });
    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, firstFinalist, 88, scoreSalt, '', EMPTY, { from: validatorA });
    await discovery.revealFinalistScore(procurementId, fallbackAgent, 77, fallbackScoreSalt, '', EMPTY, { from: validatorB });

    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.advanceProcurement(procurementId, { from: employer });

    await time.increase(4);
    await discovery.advanceProcurement(procurementId, { from: validatorB });

    const info = await manager.getJobSelectionInfo(jobId);
    assert.equal(info[1], fallbackAgent, 'fallback finalist should be promoted after first winner times out');
  });

  it('rejects advanceProcurement for nonexistent procurement ids', async () => {
    await expectRevert.unspecified(discovery.advanceProcurement(999999, { from: employer }));
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

    await discovery.commitApplication(procurementId, cA, '', EMPTY, { from: agentA });
    await discovery.commitApplication(procurementId, cB, '', EMPTY, { from: agentB });
    await time.increaseTo(proc.revealDeadline - 5);
    await discovery.revealApplication(procurementId, '', EMPTY, saltA, uriA, { from: agentA });
    await discovery.revealApplication(procurementId, '', EMPTY, saltB, uriB, { from: agentB });

    await time.increaseTo(proc.revealDeadline + 1);
    assert.equal(await discovery.isShortlistFinalizable(procurementId), true, 'shortlist should become finalizable at reveal timeout');
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
    const autonomy = await discovery.getAutonomyStatus(procurementId);
    assert.equal(autonomy.winnerFinalizable, true, 'autonomy status should expose winner finalization readiness');
    await manager.designateSelectedAgent(jobId, agentA, 100, 0, { from: owner });
    assert.equal(
      await discovery.isWinnerFinalizable(procurementId),
      false,
      'active external selection should suppress winner finalizable helper'
    );
    await time.increase(101);
    assert.equal(await discovery.isWinnerFinalizable(procurementId), true, 'winner finalization should recover once selection expires');
    await manager.setSettlementPaused(true, { from: owner });
    assert.equal(
      await discovery.isWinnerFinalizable(procurementId),
      false,
      'settlement pause should suppress finalization when designation path is reachable'
    );
    await manager.setSettlementPaused(false, { from: owner });
    await discovery.finalizeWinner(procurementId, { from: owner });

    let info = await manager.getJobSelectionInfo(jobId);
    assert.equal(info[1], agentA, 'winner should be designated as selected agent');

    await time.increase(6);
    assert.equal(await discovery.isFallbackPromotable(procurementId), true, 'fallback should become promotable');
    await discovery.promoteFallbackFinalist(procurementId, { from: employer });

    info = await manager.getJobSelectionInfo(jobId);
    assert.equal(info[1], agentB, 'fallback finalist should be promoted after timeout');

    await manager.applyForJob(jobId, '', EMPTY, EMPTY, { from: agentB });
    await manager.requestJobCompletion(jobId, 'ipfs://job/premium/final', { from: agentB });
    await manager.validateJob(jobId, '', EMPTY, { from: validatorA });
    await time.increase(2);
    await manager.finalizeJob(jobId, { from: employer });

    const claimableValidator = await discovery.canClaim(validatorA);
    assert(claimableValidator.gt(web3.utils.toBN(0)), 'validator reveal reward should be claimable');
  });

  it('returns non-finalizable (without reverting) if linked job is cancelled before winner finalization', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium-cancelled',
      payout: web3.utils.toWei('25'),
      duration: 3600,
      details: 'cancelled job path',
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
      finalistCount: 1,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 1,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('1'),
      stipendPerFinalist: web3.utils.toWei('0.5'),
      validatorRewardPerReveal: web3.utils.toWei('0.2'),
      validatorScoreBond: web3.utils.toWei('0.1'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const premiumEvent = create.logs.find((l) => l.event === 'PremiumJobCreated');
    const procurementId = premiumEvent.args.procurementId.toNumber();
    const jobId = premiumEvent.args.jobId.toNumber();

    const salt = web3.utils.soliditySha3('C');
    const uri = 'ipfs://application/C';
    const commitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'string', value: uri },
      { type: 'bytes32', value: salt }
    );

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increaseTo(proc.revealDeadline - 2);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
    await time.increaseTo(proc.revealDeadline + 1);
    await discovery.finalizeShortlist(procurementId, { from: owner });

    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://trial/C', { from: agentA });

    const scoreSalt = web3.utils.soliditySha3('scoreC');
    const scoreCommitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'address', value: validatorA },
      { type: 'uint8', value: 90 },
      { type: 'bytes32', value: scoreSalt }
    );

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    await discovery.commitFinalistScore(procurementId, agentA, scoreCommitment, '', EMPTY, { from: validatorA });
    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 90, scoreSalt, '', EMPTY, { from: validatorA });
    await time.increaseTo(proc.scoreRevealDeadline + 1);

    await manager.cancelJob(jobId, { from: employer });

    assert.equal(await discovery.isWinnerFinalizable(procurementId), false, 'cancelled linked job should not be finalizable');
    const status = await discovery.getAutonomyStatus(procurementId);
    assert.equal(status.winnerFinalizable, false, 'autonomy status should remain readable and false after cancellation');
  });



  it('rejects unauthorized commit-time application to prevent slot-griefing', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium-auth-commit',
      payout: web3.utils.toWei('10'),
      duration: 3600,
      details: 'auth at commit',
    };
    const proc = {
      commitDeadline: now + 10,
      revealDeadline: now + 20,
      finalistAcceptDeadline: now + 30,
      trialDeadline: now + 40,
      scoreCommitDeadline: now + 50,
      scoreRevealDeadline: now + 60,
      selectedAcceptanceWindow: 10,
      checkpointWindow: 0,
      finalistCount: 1,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 1,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('1'),
      stipendPerFinalist: web3.utils.toWei('0.5'),
      validatorRewardPerReveal: web3.utils.toWei('0.2'),
      validatorScoreBond: web3.utils.toWei('0.1'),
    };

    await manager.removeAdditionalAgent(agentB, { from: owner });

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const procurementId = create.logs.find((l) => l.event === 'PremiumJobCreated').args.procurementId.toNumber();

    const salt = web3.utils.soliditySha3('auth');
    const uri = 'ipfs://application/auth';
    const commitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentB },
      { type: 'string', value: uri },
      { type: 'bytes32', value: salt }
    );

    await expectRevert.unspecified(
      discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentB })
    );
  });

  it('allows employer to cancel orphan procurement and unwind locked funds', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium-cancel',
      payout: web3.utils.toWei('12'),
      duration: 3600,
      details: 'cancel path',
    };
    const proc = {
      commitDeadline: now + 10,
      revealDeadline: now + 20,
      finalistAcceptDeadline: now + 30,
      trialDeadline: now + 40,
      scoreCommitDeadline: now + 50,
      scoreRevealDeadline: now + 60,
      selectedAcceptanceWindow: 10,
      checkpointWindow: 0,
      finalistCount: 1,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 1,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('2'),
      stipendPerFinalist: web3.utils.toWei('0.5'),
      validatorRewardPerReveal: web3.utils.toWei('0.2'),
      validatorScoreBond: web3.utils.toWei('0.1'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const procurementId = create.logs.find((l) => l.event === 'PremiumJobCreated').args.procurementId.toNumber();

    const salt = web3.utils.soliditySha3('cancel');
    const uri = 'ipfs://application/cancel';
    const commitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'string', value: uri },
      { type: 'bytes32', value: salt }
    );

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increaseTo(proc.revealDeadline - 2);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
    await time.increaseTo(proc.revealDeadline + 1);
    await discovery.finalizeShortlist(procurementId, { from: owner });
    await discovery.acceptFinalist(procurementId, { from: agentA });

    const balBefore = await discovery.canClaim(agentA);
    assert.equal(balBefore.toString(), '0');

    await discovery.cancelProcurement(procurementId, { from: employer });

    const balAfter = await discovery.canClaim(agentA);
    assert.equal(balAfter.toString(), web3.utils.toWei('2'), 'finalist stake should be reclaimable after cancellation');
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'cancelled');
  });




  it('rejects cancellation after any finalist has submitted trial work', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium-cancel-after-trial',
      payout: web3.utils.toWei('15'),
      duration: 3600,
      details: 'cancel exploit guard',
    };
    const proc = {
      commitDeadline: now + 10,
      revealDeadline: now + 20,
      finalistAcceptDeadline: now + 30,
      trialDeadline: now + 40,
      scoreCommitDeadline: now + 50,
      scoreRevealDeadline: now + 60,
      selectedAcceptanceWindow: 10,
      checkpointWindow: 0,
      finalistCount: 1,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 1,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('1'),
      stipendPerFinalist: web3.utils.toWei('0.5'),
      validatorRewardPerReveal: web3.utils.toWei('0.2'),
      validatorScoreBond: web3.utils.toWei('0.1'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const procurementId = create.logs.find((l) => l.event === 'PremiumJobCreated').args.procurementId.toNumber();

    const salt = web3.utils.soliditySha3('cancel-after-trial');
    const uri = 'ipfs://application/cancel-after-trial';
    const commitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'string', value: uri },
      { type: 'bytes32', value: salt }
    );

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increaseTo(proc.revealDeadline - 2);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
    await time.increaseTo(proc.revealDeadline + 1);
    await discovery.finalizeShortlist(procurementId, { from: owner });
    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://trial/cancel-after-trial', { from: agentA });

    await expectRevert.unspecified(
      discovery.cancelProcurement(procurementId, { from: employer })
    );
  });
  it('keeps autonomy status readable after winner finalization when linked job is deleted', async () => {
    const now = (await time.latest()).toNumber();
    const premium = {
      jobSpecURI: 'ipfs://job/premium-delete-after-winner',
      payout: web3.utils.toWei('18'),
      duration: 3600,
      details: 'deleted linked job path',
    };
    const proc = {
      commitDeadline: now + 10,
      revealDeadline: now + 20,
      finalistAcceptDeadline: now + 30,
      trialDeadline: now + 40,
      scoreCommitDeadline: now + 50,
      scoreRevealDeadline: now + 60,
      selectedAcceptanceWindow: 300,
      checkpointWindow: 0,
      finalistCount: 1,
      minValidatorReveals: 1,
      maxValidatorRevealsPerFinalist: 1,
      historicalWeightBps: 2000,
      trialWeightBps: 8000,
      minReputation: 0,
      applicationStake: web3.utils.toWei('1'),
      finalistStakeTotal: web3.utils.toWei('1'),
      stipendPerFinalist: web3.utils.toWei('0.5'),
      validatorRewardPerReveal: web3.utils.toWei('0.2'),
      validatorScoreBond: web3.utils.toWei('0.1'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(premium, proc, { from: employer });
    const premiumEvent = create.logs.find((l) => l.event === 'PremiumJobCreated');
    const procurementId = premiumEvent.args.procurementId.toNumber();
    const jobId = premiumEvent.args.jobId.toNumber();

    const salt = web3.utils.soliditySha3('D');
    const uri = 'ipfs://application/D';
    const commitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'string', value: uri },
      { type: 'bytes32', value: salt }
    );

    await discovery.commitApplication(procurementId, commitment, '', EMPTY, { from: agentA });
    await time.increaseTo(proc.revealDeadline - 2);
    await discovery.revealApplication(procurementId, '', EMPTY, salt, uri, { from: agentA });
    await time.increaseTo(proc.revealDeadline + 1);
    await discovery.finalizeShortlist(procurementId, { from: owner });
    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://trial/D', { from: agentA });

    const scoreSalt = web3.utils.soliditySha3('scoreD');
    const scoreCommitment = web3.utils.soliditySha3(
      { type: 'uint256', value: procurementId },
      { type: 'address', value: agentA },
      { type: 'address', value: validatorA },
      { type: 'uint8', value: 85 },
      { type: 'bytes32', value: scoreSalt }
    );

    await time.increaseTo(proc.scoreCommitDeadline - 1);
    await discovery.commitFinalistScore(procurementId, agentA, scoreCommitment, '', EMPTY, { from: validatorA });
    await time.increaseTo(proc.scoreRevealDeadline - 1);
    await discovery.revealFinalistScore(procurementId, agentA, 85, scoreSalt, '', EMPTY, { from: validatorA });
    await time.increaseTo(proc.scoreRevealDeadline + 1);
    await discovery.finalizeWinner(procurementId, { from: owner });

    await manager.cancelJob(jobId, { from: employer });

    assert.equal(await discovery.isFallbackPromotable(procurementId), false, 'fallback check should not revert for deleted linked job');
    assert.equal(await discovery.nextActionForProcurement(procurementId), 'linked_job_missing');
    const status = await discovery.getAutonomyStatus(procurementId);
    assert.equal(status.nextAction, 'linked_job_missing', 'autonomy status should remain readable with deleted linked job');
  });
});
