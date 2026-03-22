const { time, expectEvent, expectRevert } = require("@openzeppelin/test-helpers");

const AGIJobManagerPrime = artifacts.require("AGIJobManagerPrime");
const ENSJobPages = artifacts.require("ENSJobPages");
const MockENSRegistry = artifacts.require("MockENSRegistry");
const MockNameWrapper = artifacts.require("MockNameWrapper");
const MockPublicResolver = artifacts.require("MockPublicResolver");
const MockENSJobPages = artifacts.require("MockENSJobPages");
const MockNoSupportsInterface = artifacts.require("MockNoSupportsInterface");
const MockERC20 = artifacts.require("MockERC20");
const MockERC721 = artifacts.require("MockERC721");
const AGIJobCompletionNFT = artifacts.require("AGIJobCompletionNFT");
const UriUtils = artifacts.require("UriUtils");
const BondMath = artifacts.require("BondMath");
const ReputationMath = artifacts.require("ReputationMath");
const ENSOwnership = artifacts.require("ENSOwnership");

const { expectCustomError } = require("./helpers/errors");
const { namehash } = require("./helpers/ens");

contract("AGIJobManagerPrime ENS mainnet-ready", (accounts) => {
  const [owner, employer, agent] = accounts;
  const ZERO32 = "0x" + "00".repeat(32);

  before(async () => {
    const uriUtils = await UriUtils.new({ from: owner });
    const bondMath = await BondMath.new({ from: owner });
    const reputationMath = await ReputationMath.new({ from: owner });
    const ensOwnership = await ENSOwnership.new({ from: owner });
    AGIJobManagerPrime.link("UriUtils", uriUtils.address);
    AGIJobManagerPrime.link("BondMath", bondMath.address);
    AGIJobManagerPrime.link("ReputationMath", reputationMath.address);
    AGIJobManagerPrime.link("ENSOwnership", ensOwnership.address);
  });

  async function deployPrime(token, ens, wrapper) {
    return AGIJobManagerPrime.new(
      token.address,
      "ipfs://base/",
      ens.address,
      wrapper.address,
      [ZERO32, ZERO32, ZERO32, ZERO32],
      [ZERO32, ZERO32],
      { from: owner }
    );
  }

  async function seedSettlingJob(manager, token) {
    const nft = await MockERC721.new({ from: owner });
    await manager.addOrUpdateAGIType(nft.address, 90, { from: owner });
    await nft.mint(agent, { from: owner });
    await manager.addAdditionalAgent(agent, { from: owner });
    const payout = web3.utils.toWei("5");
    await token.mint(employer, payout, { from: owner });
    await token.approve(manager.address, payout, { from: employer });
    await manager.createJob("ipfs://spec.json", payout, 10, "details", { from: employer });
    await token.mint(agent, web3.utils.toWei("2"), { from: owner });
    await token.approve(manager.address, web3.utils.toWei("2"), { from: agent });
    await manager.applyForJob(0, "agent", [], [], { from: agent });
    await manager.requestJobCompletion(0, "ipfs://completion.json", { from: agent });
    await time.increase((await manager.completionReviewPeriod()).toNumber() + 1);
  }

  it("rejects ENS hook targets without the typed interface", async () => {
    const token = await MockERC20.new({ from: owner });
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const manager = await deployPrime(token, ens, wrapper);
    const incompatible = await MockNoSupportsInterface.new({ from: owner });

    await expectRevert.unspecified(manager.setEnsJobPages(incompatible.address, { from: owner }));
  });

  it("pushes typed ENS hooks, emits observability, and supports owner repair", async () => {
    const token = await MockERC20.new({ from: owner });
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const manager = await deployPrime(token, ens, wrapper);
    const pages = await MockENSJobPages.new({ from: owner });

    const setTx = await manager.setEnsJobPages(pages.address, { from: owner });
    expectEvent(setTx, "EnsJobPagesUpdated", { oldValue: "0x0000000000000000000000000000000000000000", newValue: pages.address });

    await seedSettlingJob(manager, token);
    assert.equal((await pages.createCalls()).toString(), "1");
    assert.equal((await pages.assignCalls()).toString(), "1");
    assert.equal((await pages.completionCalls()).toString(), "1");
    assert.equal(await pages.lastEmployer(), employer);
    assert.equal(await pages.lastAgent(), agent);

    await pages.setRevertHook(4, true, { from: owner });
    const revokeTx = await manager.syncEnsHook(0, 4, false, { from: owner });
    expectEvent(revokeTx, "EnsHookAttempted", { hook: "4", jobId: "0", target: pages.address, success: false });

    await pages.setRevertHook(4, false, { from: owner });
    const repairTx = await manager.syncEnsHook(0, 4, false, { from: owner });
    expectEvent(repairTx, "EnsHookAttempted", { hook: "4", jobId: "0", target: pages.address, success: true });
  });

  it("uses issued ENS URIs for completion NFTs when enabled", async () => {
    const token = await MockERC20.new({ from: owner });
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const manager = await deployPrime(token, ens, wrapper);
    const pages = await MockENSJobPages.new({ from: owner });

    await manager.setEnsJobPages(pages.address, { from: owner });
    await manager.setUseEnsJobTokenURI(true, { from: owner });
    await seedSettlingJob(manager, token);
    await manager.finalizeJob(0, { from: employer });
    const nft1 = await AGIJobCompletionNFT.at(await manager.completionNFT());
    assert.equal(await nft1.tokenURI(0), "ens://agijob-0.alpha.jobs.agi.eth");

    const manager2 = await deployPrime(token, ens, wrapper);
    const pages2 = await MockENSJobPages.new({ from: owner });
    await manager2.setEnsJobPages(pages2.address, { from: owner });
    await manager2.setUseEnsJobTokenURI(true, { from: owner });
    await pages2.setIssued(false, { from: owner });
    await seedSettlingJob(manager2, token);
    await manager2.finalizeJob(0, { from: employer });
    const nft2 = await AGIJobCompletionNFT.at(await manager2.completionNFT());
    assert.equal(await nft2.tokenURI(0), "ipfs://completion.json");
  });

  it("enforces root name/node consistency and hyphenated previews", async () => {
    const ens = await MockENSRegistry.new({ from: owner });
    const wrapper = await MockNameWrapper.new({ from: owner });
    const resolver = await MockPublicResolver.new({ from: owner });
    const goodRoot = "alpha.jobs.agi.eth";
    const goodNode = namehash(goodRoot);

    const pages = await ENSJobPages.new(ens.address, wrapper.address, resolver.address, goodNode, goodRoot, { from: owner });
    assert.equal(await pages.jobEnsName(7), "agijob-7.alpha.jobs.agi.eth");

    try {
      await ENSJobPages.new(ens.address, wrapper.address, resolver.address, goodNode, "wrong.jobs.agi.eth", { from: owner, gas: 6_000_000 });
      assert.fail("expected constructor to revert");
    } catch (err) {
      assert.include(String(err.message), "couldn't be stored");
    }
  });
});
