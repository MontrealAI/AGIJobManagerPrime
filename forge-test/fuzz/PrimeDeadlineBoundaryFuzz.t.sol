// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-test/harness/AGIJobManagerPrimeHarness.sol";
import "forge-test/harness/AGIJobDiscoveryPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";
import "contracts/test/MockENS.sol";
import "contracts/test/MockNameWrapper.sol";

contract PrimeDeadlineBoundaryFuzz is Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    MockERC721 internal agiType;

    address internal employer = address(0xE1);
    address internal agent = address(0xA1);
    address internal validator = address(0xB1);

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
        manager.setRequiredValidatorApprovals(1);
        manager.setChallengePeriodAfterApproval(1 days);
        manager.setPremiumReputationThreshold(0);
        manager.addAdditionalAgent(agent);
        manager.addAdditionalValidator(validator);

        agiType = new MockERC721();
        agiType.mint(agent);
        manager.addOrUpdateAGIType(address(agiType), 80);

        token.mint(employer, 100_000 ether);
        token.mint(agent, 100_000 ether);
        token.mint(validator, 100_000 ether);

        vm.prank(employer);
        token.approve(address(manager), type(uint256).max);
        vm.prank(employer);
        token.approve(address(discovery), type(uint256).max);
        vm.prank(agent);
        token.approve(address(manager), type(uint256).max);
        vm.prank(agent);
        token.approve(address(discovery), type(uint256).max);
        vm.prank(validator);
        token.approve(address(manager), type(uint256).max);
        vm.prank(validator);
        token.approve(address(discovery), type(uint256).max);
    }

    function _createAssignedJob(uint256 duration) internal returns (uint256 jobId) {
        vm.prank(employer);
        jobId = manager.createJob("ipfs://job", 10 ether, duration, "details");
        vm.prank(agent);
        manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0));
    }

    function testFuzz_managerDeadlineBoundaries(uint256 durationSeed) external {
        uint256 duration = bound(durationSeed, 1 days, 7 days);
        uint256 jobId = _createAssignedJob(duration);
        (,, uint64 assignedAt,,,,,) = manager.jobTiming(jobId);

        vm.warp(uint256(assignedAt) + duration - 1);
        vm.expectRevert();
        manager.expireJob(jobId);

        vm.warp(uint256(assignedAt) + duration);
        vm.expectRevert();
        manager.expireJob(jobId);

        vm.warp(uint256(assignedAt) + duration + 1);
        manager.expireJob(jobId);
    }

    function testFuzz_discoveryPauseClockBoundaries(uint256 startSeed) external {
        uint64 start = uint64(block.timestamp + bound(startSeed, 10, 20));
        AGIJobDiscoveryPrime.PremiumJobParams memory premium = AGIJobDiscoveryPrime.PremiumJobParams({
            jobSpecURI: "ipfs://prime", payout: 10 ether, duration: 1 days, details: "prime"
        });
        AGIJobDiscoveryPrime.ProcurementParams memory proc = AGIJobDiscoveryPrime.ProcurementParams({
            commitDeadline: start + 20,
            revealDeadline: start + 40,
            finalistAcceptDeadline: start + 60,
            trialDeadline: start + 80,
            scoreCommitDeadline: start + 100,
            scoreRevealDeadline: start + 120,
            selectedAcceptanceWindow: 50,
            checkpointWindow: 0,
            finalistCount: 1,
            minValidatorReveals: 1,
            maxValidatorRevealsPerFinalist: 1,
            historicalWeightBps: 3000,
            trialWeightBps: 7000,
            minReputation: 0,
            applicationStake: 1 ether,
            finalistStakeTotal: 2 ether,
            stipendPerFinalist: 1 ether,
            validatorRewardPerReveal: 0.1 ether,
            validatorScoreBond: 0.5 ether
        });

        vm.prank(employer);
        (, uint256 pid) = discovery.createPremiumJobWithDiscovery(premium, proc);

        bytes32 salt = keccak256("app");
        bytes32 commitment = keccak256(abi.encodePacked(pid, agent, "ipfs://app", salt));
        vm.prank(agent);
        discovery.commitApplication(pid, commitment, "", new bytes32[](0));

        vm.warp(proc.commitDeadline - 1);
        vm.prank(agent);
        vm.expectRevert();
        discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app");

        vm.warp(proc.commitDeadline);
        vm.prank(agent);
        vm.expectRevert();
        discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app");

        vm.prank(manager.owner());
        discovery.pause();
        vm.warp(block.timestamp + 25);
        vm.expectRevert();
        discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app");
        vm.prank(manager.owner());
        discovery.unpause();

        vm.warp(proc.commitDeadline + 1);
        uint256 pausedFor = 25;
        vm.warp(proc.commitDeadline + pausedFor + 1);
        vm.prank(agent);
        discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app");
    }
}
