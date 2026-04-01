// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-test/harness/AGIJobManagerPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";
import "contracts/test/MockENS.sol";
import "contracts/test/MockNameWrapper.sol";

contract PrimeManagerSettlementFuzz is Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    MockERC721 internal agiType;

    address internal employer = address(0xE1);
    address internal agent = address(0xA1);
    address internal validatorA = address(0xB1);
    address internal validatorB = address(0xB2);
    address internal validatorC = address(0xB3);

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
        manager.setPremiumReputationThreshold(0);
        manager.setRequiredValidatorApprovals(2);
        manager.setRequiredValidatorDisapprovals(2);
        manager.setVoteQuorum(2);
        manager.setChallengePeriodAfterApproval(1 days);
        manager.addAdditionalAgent(agent);
        manager.addAdditionalValidator(validatorA);
        manager.addAdditionalValidator(validatorB);
        manager.addAdditionalValidator(validatorC);

        agiType = new MockERC721();
        agiType.mint(agent);
        manager.addOrUpdateAGIType(address(agiType), 80);

        address[5] memory funded = [employer, agent, validatorA, validatorB, validatorC];
        for (uint256 i = 0; i < funded.length; ++i) {
            token.mint(funded[i], 100_000 ether);
            vm.prank(funded[i]);
            token.approve(address(manager), type(uint256).max);
        }
    }

    function _createRequestedCompletionJob(uint256 payout, uint256 duration) internal returns (uint256 jobId) {
        vm.prank(employer);
        jobId = manager.createJob("ipfs://job", payout, duration, "details");
        vm.prank(agent);
        manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0));
        vm.prank(agent);
        manager.requestJobCompletion(jobId, "ipfs://done");
    }

    function _votePrefix(uint256 jobId, uint256 approvals, uint256 disapprovals) internal {
        address[3] memory validators = [validatorA, validatorB, validatorC];
        for (uint256 i = 0; i < approvals && i < validators.length; ++i) {
            vm.startPrank(validators[i]);
            try manager.validateJob(jobId, "", new bytes32[](0)) {} catch {}
            vm.stopPrank();
        }
        for (uint256 i = approvals; i < approvals + disapprovals && i < validators.length; ++i) {
            vm.startPrank(validators[i]);
            try manager.disapproveJob(jobId, "", new bytes32[](0)) {} catch {}
            vm.stopPrank();
        }
    }

    function testFuzz_finalizeClassificationMatchesVotes(
        uint96 payoutSeed,
        uint64 durationSeed,
        uint8 approvalsSeed,
        uint8 disapprovalsSeed
    ) external {
        uint256 payout = bound(uint256(payoutSeed), 5 ether, 100 ether);
        uint256 duration = bound(uint256(durationSeed), 1 days, 7 days);
        uint256 approvals = bound(uint256(approvalsSeed), 0, 3);
        uint256 disapprovals = bound(uint256(disapprovalsSeed), 0, 3 - approvals);

        uint256 jobId = _createRequestedCompletionJob(payout, duration);
        _votePrefix(jobId, approvals, disapprovals);

        (,,,,, uint64 validatorApprovedAt,,) = manager.jobTiming(jobId);
        (bool completedBefore,, bool disputedBefore,,,) = manager.jobFlags(jobId);
        assertFalse(completedBefore);

        uint256 managerBalanceBefore = token.balanceOf(address(manager));
        uint256 lockedBefore = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(managerBalanceBefore, lockedBefore, "manager insolvent before finalize");

        if (disputedBefore) {
            vm.expectRevert();
            manager.finalizeJob(jobId);
            return;
        }

        if (approvals >= 2) {
            vm.warp(uint256(validatorApprovedAt) + manager.challengePeriodAfterApproval());
            vm.expectRevert();
            manager.finalizeJob(jobId);
        }

        (,,, uint64 completionRequestedAt,,,,) = manager.jobTiming(jobId);
        vm.warp(
            uint256(completionRequestedAt) + manager.completionReviewPeriod() + manager.challengePeriodAfterApproval()
                + 2
        );
        manager.finalizeJob(jobId);

        (
            bool completed,
            bool completionRequested,
            bool disputed,
            bool expired,
            bool escrowReleased,
            bool validatorApproved
        ) = manager.jobFlags(jobId);
        (uint256 approvalsCount, uint256 disapprovalsCount, uint256 validatorCount) =
            manager.jobValidatorParticipation(jobId);

        assertTrue(completionRequested, "completion request cleared unexpectedly");
        assertFalse(expired, "completed path cannot expire");
        assertEq(validatorCount, approvalsCount + disapprovalsCount, "validator list drift after finalize");

        uint256 totalVotes = approvalsCount + disapprovalsCount;
        if (totalVotes == 0) {
            assertTrue(completed, "zero-vote path should complete after review window");
            assertFalse(disputed, "zero-vote path should not dispute");
        } else if (totalVotes < manager.voteQuorum() || approvalsCount == disapprovalsCount) {
            assertFalse(completed, "low-quorum/tie path should not complete");
            assertTrue(disputed, "low-quorum/tie path should dispute");
        } else if (approvalsCount > disapprovalsCount) {
            assertTrue(completed, "approval majority should complete");
            assertFalse(disputed, "approval majority should not dispute");
            assertTrue(escrowReleased, "completion should release escrow");
            assertTrue(validatorApproved, "approval majority should preserve early approval flag");
        } else {
            assertTrue(completed, "disapproval majority should settle employer win");
            assertFalse(disputed, "employer-win settlement should resolve dispute state");
            assertTrue(escrowReleased, "employer win should release escrow");
        }

        uint256 lockedAfter = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), lockedAfter, "manager insolvent after finalize");

        vm.expectRevert();
        manager.finalizeJob(jobId);
    }

    function testFuzz_terminalSettlementDoesNotDoubleSpendValidatorBonds(
        uint96 payoutSeed,
        bool employerWins,
        uint8 approvalSeed,
        uint8 disapprovalSeed
    ) external {
        uint256 payout = bound(uint256(payoutSeed), 10 ether, 90 ether);
        uint256 jobId = _createRequestedCompletionJob(payout, 3 days);
        uint256 approvals = bound(uint256(approvalSeed), 0, 1);
        uint256 disapprovals = bound(uint256(disapprovalSeed), 0, 3 - approvals);
        _votePrefix(jobId, approvals, disapprovals);

        // Force a single dispute-opening path, then resolve it once.
        (,, bool disputedBefore,,,) = manager.jobFlags(jobId);
        if (!disputedBefore) {
            vm.prank(agent);
            try manager.disputeJob(jobId) {} catch {}
        }

        (,, bool disputedAfter,,,) = manager.jobFlags(jobId);
        if (!disputedAfter) return;

        uint256 lockedValidatorBefore = manager.lockedValidatorBonds();
        uint256 lockedDisputeBefore = manager.lockedDisputeBonds();

        (,,,, uint64 disputedAt,,,) = manager.jobTiming(jobId);
        vm.warp(uint256(disputedAt) + manager.disputeReviewPeriod() + 2);
        manager.resolveStaleDispute(jobId, employerWins);

        assertLe(manager.lockedValidatorBonds(), lockedValidatorBefore, "validator bonds increased on resolution");
        assertLe(manager.lockedDisputeBonds(), lockedDisputeBefore, "dispute bonds increased on resolution");

        vm.expectRevert();
        manager.resolveStaleDispute(jobId, employerWins);

        uint256 lockedAfter = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), lockedAfter, "manager insolvent after dispute resolution");
    }
}
