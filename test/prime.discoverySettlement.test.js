const assert = require('assert');
const { time, expectRevert } = require('@openzeppelin/test-helpers');

const AGIJobManagerPrime = artifacts.require('AGIJobManagerPrime');
const AGIJobDiscoveryPrime = artifacts.require('AGIJobDiscoveryPrime');
const MockERC20 = artifacts.require('MockERC20');
const MockENS = artifacts.require('MockENS');
const MockNameWrapper = artifacts.require('MockNameWrapper');

const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');

const ZERO32 = '0x' + '00'.repeat(32);
const EMPTY_PROOF = [];

function toLeaf(addr) {
  return web3.utils.soliditySha3({ t: 'address', v: addr });
}

contract('Prime discovery + settlement integration', (accounts) => {
  const [owner, employer, agentA, agentB, validatorA, validatorB, outsider] = accounts;

  let token;
  let ens;
  let nameWrapper;
  let manager;
  let discovery;

  beforeEach(async () => {
    token = await MockERC20.new({ from: owner });
    ens = await MockENS.new({ from: owner });
    nameWrapper = await MockNameWrapper.new({ from: owner });

    manager = await AGIJobManagerPrime.new(
      token.address,
      'ipfs://base/',
      ens.address,
      nameWrapper.address,
      [ZERO32, ZERO32, ZERO32, ZERO32],
      [ZERO32, ZERO32],
      { from: owner }
    );

    discovery = await AGIJobDiscoveryPrime.new(manager.address, { from: owner });
    await manager.setDiscoveryModule(discovery.address, { from: owner });

    await manager.addAdditionalAgent(agentA, { from: owner });
    await manager.addAdditionalAgent(agentB, { from: owner });
    await manager.addAdditionalValidator(validatorA, { from: owner });
    await manager.addAdditionalValidator(validatorB, { from: owner });

    await manager.setRequiredValidatorApprovals(1, { from: owner });
    await manager.setChallengePeriodAfterApproval(1, { from: owner });

    for (const acct of [employer, agentA, agentB, validatorA, validatorB, outsider]) {
      await token.mint(acct, web3.utils.toWei('500'), { from: owner });
      await token.approve(manager.address, web3.utils.toWei('500'), { from: acct });
      await token.approve(discovery.address, web3.utils.toWei('500'), { from: acct });
    }
  });

  it('supports open-first-come settlement flow', async () => {
    const payout = web3.utils.toWei('100');
    const tx = await manager.createConfiguredJob('ipfs://spec', payout, 3600, 'open', 0, ZERO32, { from: employer });
    const jobId = tx.logs[0].args.jobId.toNumber();

    await manager.applyForJob(jobId, '', EMPTY_PROOF, EMPTY_PROOF, { from: agentA });
    await manager.requestJobCompletion(jobId, 'ipfs://done', { from: agentA });
    await manager.validateJob(jobId, '', EMPTY_PROOF, { from: validatorA });
    await time.increase(2);
    await manager.finalizeJob(jobId, { from: outsider });

    const info = await manager.jobs(jobId);
    assert.equal(info.completed, true, 'job must be completed');
  });

  it('supports selected-agent premium winner designation and fallback promotion', async () => {
    await manager.setPremiumReputationThreshold(0, { from: owner });

    const now = await time.latest();
    const proc = {
      commitDeadline: now.addn(10).toNumber(),
      revealDeadline: now.addn(20).toNumber(),
      finalistAcceptDeadline: now.addn(30).toNumber(),
      trialDeadline: now.addn(40).toNumber(),
      scoreCommitDeadline: now.addn(50).toNumber(),
      scoreRevealDeadline: now.addn(60).toNumber(),
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
      validatorRewardPerReveal: web3.utils.toWei('1'),
      validatorScoreBond: web3.utils.toWei('1'),
    };

    const create = await discovery.createPremiumJobWithDiscovery(
      ['ipfs://premium-spec', web3.utils.toWei('50'), 3600, 'premium'],
      Object.values(proc),
      { from: employer }
    );

    const jobId = create.logs.find((l) => l.event === 'PremiumJobCreated').args.jobId.toNumber();
    const procurementId = create.logs.find((l) => l.event === 'PremiumJobCreated').args.procurementId.toNumber();

    const saltA = web3.utils.soliditySha3('saltA');
    const saltB = web3.utils.soliditySha3('saltB');
    const uriA = 'ipfs://app-a';
    const uriB = 'ipfs://app-b';

    await discovery.commitApplication(
      procurementId,
      web3.utils.soliditySha3({ t: 'uint256', v: procurementId }, { t: 'address', v: agentA }, { t: 'string', v: uriA }, { t: 'bytes32', v: saltA }),
      { from: agentA }
    );
    await discovery.commitApplication(
      procurementId,
      web3.utils.soliditySha3({ t: 'uint256', v: procurementId }, { t: 'address', v: agentB }, { t: 'string', v: uriB }, { t: 'bytes32', v: saltB }),
      { from: agentB }
    );

    await time.increaseTo(now.addn(12));
    await discovery.revealApplication(procurementId, '', EMPTY_PROOF, saltA, uriA, { from: agentA });
    await discovery.revealApplication(procurementId, '', EMPTY_PROOF, saltB, uriB, { from: agentB });

    await time.increaseTo(now.addn(21));
    await discovery.finalizeShortlist(procurementId, { from: outsider });
    await discovery.acceptFinalist(procurementId, { from: agentA });
    await discovery.acceptFinalist(procurementId, { from: agentB });
    await discovery.submitTrial(procurementId, 'ipfs://trial-a', { from: agentA });
    await discovery.submitTrial(procurementId, 'ipfs://trial-b', { from: agentB });

    await time.increaseTo(now.addn(45));
    const scoreSaltA = web3.utils.soliditySha3('scoreA');
    await discovery.commitFinalistScore(
      procurementId,
      agentA,
      web3.utils.soliditySha3({ t: 'uint256', v: procurementId }, { t: 'address', v: agentA }, { t: 'address', v: validatorA }, { t: 'uint8', v: 95 }, { t: 'bytes32', v: scoreSaltA }),
      '',
      EMPTY_PROOF,
      { from: validatorA }
    );

    await time.increaseTo(now.addn(55));
    await discovery.revealFinalistScore(procurementId, agentA, 95, scoreSaltA, '', EMPTY_PROOF, { from: validatorA });

    await time.increaseTo(now.addn(61));
    await discovery.finalizeWinner(procurementId, { from: outsider });

    const selection = await manager.getJobSelectionInfo(jobId);
    const selected = selection[2];
    assert.equal(selected, agentA, 'agent A should be selected');

    await time.increase(6);
    await discovery.promoteFallbackFinalist(procurementId, { from: outsider });
    const selectionAfter = await manager.getJobSelectionInfo(jobId);
    assert.equal(selectionAfter[2], agentB, 'fallback finalist should be promoted');
  });

  it('supports per-job merkle intake flow', async () => {
    const payout = web3.utils.toWei('20');
    const tx = await manager.createConfiguredJob('ipfs://spec-merkle', payout, 3600, 'merkle', 2, ZERO32, { from: employer });
    const jobId = tx.logs[0].args.jobId.toNumber();

    const tree = new MerkleTree([Buffer.from(toLeaf(agentA).slice(2), 'hex')], keccak256, { sortPairs: true });
    const root = '0x' + tree.getRoot().toString('hex');
    const proof = tree.getHexProof(Buffer.from(toLeaf(agentA).slice(2), 'hex'));

    await manager.setPerJobAgentRoot(jobId, root, 100, { from: owner });
    await manager.applyForJob(jobId, '', EMPTY_PROOF, proof, { from: agentA });

    await expectRevert(
      manager.applyForJob(jobId, '', EMPTY_PROOF, EMPTY_PROOF, { from: agentB }),
      'InvalidState'
    );
  });
});
