// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-test/harness/prime/AGIJobManagerPrimeHarness.sol";
import "forge-test/harness/prime/AGIJobDiscoveryPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";

contract PrimeDeadlineBoundaryFuzz is Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    MockERC721 internal agiType;

    address internal employer = address(0x11);
    address internal agent = address(0x22);
    address internal validator = address(0x33);

    function setUp() external {
        token = new MockERC20();
        bytes32[4] memory rootNodes;
        bytes32[2] memory merkleRoots;
        manager = new AGIJobManagerPrimeHarness(address(token), "", address(0), address(0), rootNodes, merkleRoots);
        discovery = new AGIJobDiscoveryPrimeHarness(address(manager));
        agiType = new MockERC721();

        vm.startPrank(manager.owner());
        manager.addOrUpdateAGIType(address(agiType), 70);
        manager.addAdditionalAgent(agent);
        manager.addAdditionalValidator(validator);
        manager.setVoteQuorum(1);
        manager.setRequiredValidatorApprovals(1);
        manager.setRequiredValidatorDisapprovals(1);
        manager.setSettlementPaused(false);
        manager.setDiscoveryModule(address(discovery));
        vm.stopPrank();

        agiType.mint(agent);
        token.mint(employer, 1_000_000 ether);
        token.mint(agent, 1_000_000 ether);
        token.mint(validator, 1_000_000 ether);
        vm.prank(employer); token.approve(address(manager), type(uint256).max);
        vm.prank(employer); token.approve(address(discovery), type(uint256).max);
        vm.prank(agent); token.approve(address(manager), type(uint256).max);
        vm.prank(agent); token.approve(address(discovery), type(uint256).max);
        vm.prank(validator); token.approve(address(manager), type(uint256).max);
        vm.prank(validator); token.approve(address(discovery), type(uint256).max);
    }

    function _createReviewJob() internal returns (uint256 jobId) {
        vm.prank(employer);
        jobId = manager.createJob("ipfs://spec", 20 ether, 2 days, "prime");
        vm.prank(agent);
        manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0));
        vm.prank(agent);
        manager.requestJobCompletion(jobId, "ipfs://done");
    }

    function testFuzz_manager_reviewBoundaries_and_pauseBaseline(uint256 tinyWarp, bool pauseAtBoundary) external {
        uint256 jobId = _createReviewJob();
        uint256 deadline = uint256(manager.jobCompletionRequestedAt(jobId)) + manager.completionReviewPeriod();

        vm.warp(deadline - 1);
        vm.prank(validator);
        manager.validateJob(jobId, "", new bytes32[](0));

        if (pauseAtBoundary) {
            vm.prank(manager.owner());
            manager.pause();
            uint256 before = manager.effectiveTimestampForJob(jobId);
            vm.warp(block.timestamp + bound(tinyWarp, 0, 10 hours));
            assertEq(manager.effectiveTimestampForJob(jobId), before);
            vm.prank(manager.owner());
            manager.unpause();
        }

        vm.warp(deadline + 1);
        vm.prank(validator);
        vm.expectRevert();
        manager.disapproveJob(jobId, "", new bytes32[](0));
    }

    function testFuzz_discovery_pauseBoundaries(uint256 tinyWarp, bool pauseExactlyAtReveal) external {
        AGIJobDiscoveryPrime.PremiumJobParams memory job = AGIJobDiscoveryPrime.PremiumJobParams({
            jobSpecURI: "ipfs://spec",
            payout: 40 ether,
            duration: 5 days,
            details: "prime"
        });
        uint64 nowTs = uint64(block.timestamp + 1);
        AGIJobDiscoveryPrime.ProcurementParams memory p = AGIJobDiscoveryPrime.ProcurementParams({
            commitDeadline: nowTs + 1 days,
            revealDeadline: nowTs + 2 days,
            finalistAcceptDeadline: nowTs + 3 days,
            trialDeadline: nowTs + 4 days,
            scoreCommitDeadline: nowTs + 5 days,
            scoreRevealDeadline: nowTs + 6 days,
            selectedAcceptanceWindow: 1 days,
            checkpointWindow: 1 days,
            finalistCount: 1,
            minValidatorReveals: 1,
            maxValidatorRevealsPerFinalist: 2,
            historicalWeightBps: 5_000,
            trialWeightBps: 5_000,
            minReputation: 0,
            applicationStake: 1 ether,
            finalistStakeTotal: 2 ether,
            stipendPerFinalist: 1 ether,
            validatorRewardPerReveal: 0.5 ether,
            validatorScoreBond: 0.5 ether
        });
        vm.prank(employer);
        (, uint256 procurementId) = discovery.createPremiumJobWithDiscovery(job, p);

        string memory appUri = "ipfs://app";
        bytes32 salt = keccak256("salt");
        bytes32 commitment = keccak256(abi.encodePacked(procurementId, agent, appUri, salt));
        vm.prank(agent);
        discovery.commitApplication(procurementId, commitment, "", new bytes32[](0));

        uint256 revealBoundary = p.commitDeadline + 1;
        vm.warp(revealBoundary);
        if (pauseExactlyAtReveal) {
            vm.prank(discovery.owner());
            discovery.pause();
            uint256 frozen = discovery.effectiveTimestampForProcurement(procurementId);
            vm.warp(block.timestamp + bound(tinyWarp, 1, 12 hours));
            assertEq(discovery.effectiveTimestampForProcurement(procurementId), frozen);
            vm.prank(discovery.owner());
            discovery.unpause();
        }

        vm.prank(agent);
        discovery.revealApplication(procurementId, "", new bytes32[](0), salt, appUri);
        assertTrue(discovery.isShortlistFinalizable(procurementId) || bytes(discovery.nextActionForProcurement(procurementId)).length > 0);
    }
}
