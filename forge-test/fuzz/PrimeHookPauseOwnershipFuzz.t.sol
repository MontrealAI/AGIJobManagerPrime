// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-test/harness/AGIJobManagerPrimeHarness.sol";
import "forge-test/harness/AGIJobDiscoveryPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";
import "contracts/test/MockENS.sol";
import "contracts/test/MockNameWrapper.sol";
import "contracts/test/MockENSJobPages.sol";
import "contracts/test/MockENSJobPagesMalformed.sol";
import "contracts/test/HookGasBurner.sol";
import "contracts/utils/BusinessOwnable2Step.sol";

contract PrimeHookPauseOwnershipFuzz is Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    MockERC721 internal agiType;
    MockENSJobPages internal healthyHook;
    MockENSJobPagesMalformed internal malformedHook;
    HookGasBurner internal burnerHook;

    address internal employer = address(0xE1);
    address internal agent = address(0xA1);
    address internal validatorA = address(0xB1);
    address internal validatorB = address(0xB2);

    function setUp() external {
        token = new MockERC20();
        bytes32[4] memory rootNodes;
        bytes32[2] memory merkleRoots;
        manager = new AGIJobManagerPrimeHarness(
            address(token),
            "ipfs://base",
            address(new MockENS()),
            address(new MockNameWrapper()),
            rootNodes,
            merkleRoots
        );
        discovery = new AGIJobDiscoveryPrimeHarness(address(manager));
        manager.setDiscoveryModule(address(discovery));
        manager.setPremiumReputationThreshold(0);
        manager.setRequiredValidatorApprovals(1);
        manager.setRequiredValidatorDisapprovals(1);
        manager.setVoteQuorum(1);
        manager.setChallengePeriodAfterApproval(1 days);
        manager.addAdditionalAgent(agent);
        manager.addAdditionalValidator(validatorA);
        manager.addAdditionalValidator(validatorB);

        agiType = new MockERC721();
        agiType.mint(agent);
        manager.addOrUpdateAGIType(address(agiType), 80);

        healthyHook = new MockENSJobPages();
        malformedHook = new MockENSJobPagesMalformed();
        burnerHook = new HookGasBurner();
        manager.setEnsJobPages(address(healthyHook));

        address[4] memory funded = [employer, agent, validatorA, validatorB];
        for (uint256 i = 0; i < funded.length; ++i) {
            token.mint(funded[i], 100_000 ether);
            vm.prank(funded[i]);
            token.approve(address(manager), type(uint256).max);
            vm.prank(funded[i]);
            token.approve(address(discovery), type(uint256).max);
        }
    }

    function _createDiscoveryProcurement(uint64 start)
        internal
        returns (AGIJobDiscoveryPrime.ProcurementParams memory proc, uint256 pid)
    {
        AGIJobDiscoveryPrime.PremiumJobParams memory premium = AGIJobDiscoveryPrime.PremiumJobParams({
            jobSpecURI: "ipfs://prime", payout: 10 ether, duration: 1 days, details: "prime"
        });
        proc = AGIJobDiscoveryPrime.ProcurementParams({
            commitDeadline: start + 20,
            revealDeadline: start + 40,
            finalistAcceptDeadline: start + 60,
            trialDeadline: start + 80,
            scoreCommitDeadline: start + 100,
            scoreRevealDeadline: start + 120,
            selectedAcceptanceWindow: 60,
            checkpointWindow: 0,
            finalistCount: 1,
            minValidatorReveals: 1,
            maxValidatorRevealsPerFinalist: 2,
            historicalWeightBps: 3000,
            trialWeightBps: 7000,
            minReputation: 0,
            applicationStake: 1 ether,
            finalistStakeTotal: 2 ether,
            stipendPerFinalist: 1 ether,
            validatorRewardPerReveal: 0.25 ether,
            validatorScoreBond: 0.5 ether
        });
        vm.prank(employer);
        (, pid) = discovery.createPremiumJobWithDiscovery(premium, proc);
    }

    function testFuzz_hookFailuresNeverCorruptManagerAccounting(uint256 durationSeed, uint8 hookMode) external {
        address hook = address(healthyHook);
        if (hookMode % 3 == 1) {
            malformedHook.setRevertOnHook(true);
            hook = address(malformedHook);
        } else if (hookMode % 3 == 2) {
            hook = address(burnerHook);
        }
        manager.setEnsJobPages(hook);

        vm.prank(employer);
        uint256 jobId = manager.createConfiguredJob(
            "ipfs://job",
            12 ether,
            bound(durationSeed, 1 days, 5 days),
            "details",
            AGIJobManagerPrime.IntakeMode.OpenFirstCome,
            bytes32(0)
        );

        uint256 balanceBeforeApply = token.balanceOf(address(manager));
        vm.prank(agent);
        manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0));
        assertGe(token.balanceOf(address(manager)), balanceBeforeApply, "hook should not leak funds during apply");

        vm.prank(agent);
        manager.requestJobCompletion(jobId, "ipfs://done");
        vm.prank(validatorA);
        manager.validateJob(jobId, "", new bytes32[](0));
        vm.warp(block.timestamp + manager.challengePeriodAfterApproval() + 1);
        manager.finalizeJob(jobId);

        uint256 locked = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), locked, "best-effort hook broke solvency");
        assertEq(manager.completionNFT().nextTokenId(), 1, "true completion path should mint exactly one NFT");
    }

    function testFuzz_pauseClockDoesNotDoubleCountOrSkipDeadlines(uint32 pauseA, uint32 pauseB) external {
        (AGIJobDiscoveryPrime.ProcurementParams memory proc, uint256 pid) =
            _createDiscoveryProcurement(uint64(block.timestamp + 10));

        bytes32 salt = keccak256("app");
        bytes32 commitment = keccak256(abi.encodePacked(pid, agent, "ipfs://app", salt));
        vm.prank(agent);
        discovery.commitApplication(pid, commitment, "", new bytes32[](0));

        vm.warp(proc.commitDeadline - 1);
        vm.prank(discovery.owner());
        discovery.pause();
        uint256 pauseLenA = bound(uint256(pauseA), 1, 25);
        vm.warp(block.timestamp + pauseLenA);
        vm.prank(discovery.owner());
        discovery.unpause();

        vm.warp(proc.commitDeadline + pauseLenA - 1);
        vm.prank(agent);
        vm.expectRevert();
        discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app");

        vm.prank(discovery.owner());
        discovery.pause();
        uint256 pauseLenB = bound(uint256(pauseB), 1, 25);
        vm.warp(block.timestamp + pauseLenB);
        vm.prank(discovery.owner());
        discovery.unpause();

        vm.warp(proc.commitDeadline + pauseLenA + pauseLenB + 1);
        vm.prank(agent);
        discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app");

        (,,,,, uint64 pauseBaseline,,,,,,,,,,,,,,,) = discovery.procurementView(pid);
        assertEq(pauseBaseline, 0, "procurement baseline should remain anchored to creation-time paused seconds");
    }

    function testFuzz_rewardAccountingHoldsUnderQuorumAndMedianTies(uint8 scoreA, uint8 scoreB) external {
        (AGIJobDiscoveryPrime.ProcurementParams memory proc, uint256 pid) =
            _createDiscoveryProcurement(uint64(block.timestamp + 10));
        bytes32 salt = keccak256("app");
        vm.prank(agent);
        discovery.commitApplication(
            pid, keccak256(abi.encodePacked(pid, agent, "ipfs://app", salt)), "", new bytes32[](0)
        );
        vm.warp(proc.commitDeadline + 1);
        vm.prank(agent);
        discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app");
        vm.warp(proc.revealDeadline + 1);
        discovery.finalizeShortlist(pid);
        vm.prank(agent);
        discovery.acceptFinalist(pid);
        vm.prank(agent);
        discovery.submitTrial(pid, "ipfs://trial");

        vm.warp(proc.trialDeadline + 1);
        uint8 boundedA = uint8(bound(scoreA, 0, 100));
        uint8 boundedB = uint8(bound(scoreB, 0, 100));
        bytes32 saltA = keccak256("a");
        bytes32 saltB = keccak256("b");
        vm.prank(validatorA);
        discovery.commitFinalistScore(
            pid, agent, keccak256(abi.encodePacked(pid, agent, validatorA, boundedA, saltA)), "", new bytes32[](0)
        );
        vm.prank(validatorB);
        discovery.commitFinalistScore(
            pid, agent, keccak256(abi.encodePacked(pid, agent, validatorB, boundedB, saltB)), "", new bytes32[](0)
        );
        vm.warp(proc.scoreCommitDeadline + 1);
        vm.prank(validatorA);
        discovery.revealFinalistScore(pid, agent, boundedA, saltA, "", new bytes32[](0));

        vm.warp(proc.scoreRevealDeadline + 1);
        discovery.finalizeWinner(pid);

        uint256 validatorClaimable = discovery.claimable(validatorA) + discovery.claimable(validatorB);
        uint256 totalRewardBudget =
            uint256(proc.finalistCount) * uint256(proc.maxValidatorRevealsPerFinalist) * proc.validatorRewardPerReveal;
        uint256 totalBondPool = proc.validatorScoreBond * 2;
        assertLe(
            validatorClaimable,
            totalRewardBudget + totalBondPool,
            "validator reward+refund exceeded reward budget plus validator bonds"
        );
    }

    function testFuzz_twoStepOwnershipAndRenounceGuards(address newOwner, address outsider) external {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != discovery.owner());
        vm.assume(outsider != newOwner);

        discovery.transferOwnership(newOwner);
        assertEq(discovery.pendingOwner(), newOwner, "pending owner not recorded");

        vm.prank(outsider);
        vm.expectRevert(BusinessOwnable2Step.NotPendingOwner.selector);
        discovery.acceptOwnership();

        vm.prank(newOwner);
        discovery.acceptOwnership();
        assertEq(discovery.owner(), newOwner, "ownership acceptance failed");

        vm.prank(newOwner);
        vm.expectRevert(AGIJobDiscoveryPrime.RenounceOwnershipDisabled.selector);
        discovery.renounceOwnership();
    }
}
