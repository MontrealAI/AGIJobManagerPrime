// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "forge-test/harness/AGIJobManagerPrimeHarness.sol";
import "forge-test/harness/AGIJobDiscoveryPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";
import "contracts/test/MockENS.sol";
import "contracts/test/MockNameWrapper.sol";
import "contracts/test/MockENSJobPages.sol";
import "contracts/test/MockENSJobPagesMalformed.sol";

contract PrimeProtocolHandler is Test {
    AGIJobManagerPrimeHarness public manager;
    AGIJobDiscoveryPrimeHarness public discovery;
    MockERC20 public token;

    address public owner;
    address public moderator;
    address[] public employers;
    address[] public agents;
    address[] public validators;
    address[] public actors;

    mapping(uint256 => uint256) public snapshotFingerprint;
    mapping(uint256 => bool) public snapshotTaken;

    uint256 internal constant MAX_HANDLER_JOBS = 32;
    uint256 internal constant MAX_HANDLER_PROCUREMENTS = 24;

    constructor(AGIJobManagerPrimeHarness _manager, AGIJobDiscoveryPrimeHarness _discovery, MockERC20 _token) {
        manager = _manager;
        discovery = _discovery;
        token = _token;
        owner = manager.owner();
        moderator = address(0xBEEF);

        MockERC721 agiType = new MockERC721();
        MockENSJobPages pages = new MockENSJobPages();
        MockENSJobPagesMalformed malformed = new MockENSJobPagesMalformed();

        vm.startPrank(owner);
        manager.setDiscoveryModule(address(discovery));
        manager.addModerator(moderator);
        manager.addOrUpdateAGIType(address(agiType), 80);
        manager.setRequiredValidatorApprovals(1);
        manager.setRequiredValidatorDisapprovals(1);
        manager.setVoteQuorum(1);
        manager.setPremiumReputationThreshold(0);
        manager.setChallengePeriodAfterApproval(1 days);
        manager.setEnsJobPages(address(pages));
        vm.stopPrank();

        for (uint256 i = 0; i < 3; ++i) {
            address employer = address(uint160(0x1000 + i));
            address agent = address(uint160(0x2000 + i));
            address validator = address(uint160(0x3000 + i));
            employers.push(employer);
            agents.push(agent);
            validators.push(validator);
            actors.push(employer);
            actors.push(agent);
            actors.push(validator);

            token.mint(employer, 1_000_000 ether);
            token.mint(agent, 1_000_000 ether);
            token.mint(validator, 1_000_000 ether);

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

            agiType.mint(agent);
            vm.prank(owner);
            manager.addAdditionalAgent(agent);
            vm.prank(owner);
            manager.addAdditionalValidator(validator);
        }

        actors.push(owner);
        actors.push(moderator);
        token.mint(moderator, 100_000 ether);
        vm.prank(moderator);
        token.approve(address(manager), type(uint256).max);

        // prevent warnings about unused hostile hook by toggling it once
        malformed.setRevertOnHook(true);
        malformed.setTokenURIBytes(hex"00");
    }

    function actorsView() external view returns (address[] memory) {
        return actors;
    }

    function _boundTime(uint256 seed) internal {
        uint256 dt = bound(seed, 0, 7);
        if (dt == 0) vm.warp(block.timestamp + 1);
        else if (dt == 1) vm.warp(block.timestamp + 1 days - 1);
        else if (dt == 2) vm.warp(block.timestamp + 1 days);
        else if (dt == 3) vm.warp(block.timestamp + 1 days + 1);
        else if (dt == 4) vm.warp(block.timestamp + 7 days);
        else if (dt == 5) vm.warp(block.timestamp + 15 days);
        else if (dt == 6) vm.warp(block.timestamp + 30 days);
        else vm.warp(block.timestamp + 90 days);
    }

    function warp(uint256 seed) external {
        _boundTime(seed);
    }

    function togglePauses(uint256 seed) external {
        vm.startPrank(owner);
        manager.setSettlementPaused((seed & 1) == 1);
        if ((seed & 2) == 2) manager.pause();
        else manager.unpause();
        if ((seed & 4) == 4) discovery.pause();
        else if (discovery.paused()) discovery.unpause();
        discovery.setIntakePaused((seed & 8) == 8);
        vm.stopPrank();
    }

    function createManagerJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed, bool selectedOnly)
        external
    {
        if (manager.nextJobId() >= MAX_HANDLER_JOBS) return;
        address employer = employers[bound(employerSeed, 0, employers.length - 1)];
        vm.prank(employer);
        try manager.createConfiguredJob(
            "ipfs://job",
            bound(payoutSeed, 1 ether, 80 ether),
            bound(durationSeed, 1 hours, 10 days),
            "details",
            selectedOnly
                ? AGIJobManagerPrime.IntakeMode.SelectedAgentOnly
                : AGIJobManagerPrime.IntakeMode.OpenFirstCome,
            bytes32(0)
        ) returns (
            uint256 jobId
        ) {
            if (selectedOnly) {
                vm.prank(owner);
                try manager.designateSelectedAgent(
                    jobId, agents[jobId % agents.length], 2 days, uint64(jobId % 2 == 0 ? 1 days : 0)
                ) {}
                    catch {}
            }
        } catch {}
    }

    function createDiscoveryJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed, uint256 cfgSeed)
        external
    {
        if (manager.nextJobId() >= MAX_HANDLER_JOBS) return;
        address employer = employers[bound(employerSeed, 0, employers.length - 1)];
        uint64 start = uint64(block.timestamp + 10);
        AGIJobDiscoveryPrime.PremiumJobParams memory premium = AGIJobDiscoveryPrime.PremiumJobParams({
            jobSpecURI: "ipfs://prime",
            payout: bound(payoutSeed, 5 ether, 60 ether),
            duration: bound(durationSeed, 1 days, 7 days),
            details: "prime"
        });
        AGIJobDiscoveryPrime.ProcurementParams memory proc = AGIJobDiscoveryPrime.ProcurementParams({
            commitDeadline: start + 20,
            revealDeadline: start + 40,
            finalistAcceptDeadline: start + 60,
            trialDeadline: start + 80,
            scoreCommitDeadline: start + 100,
            scoreRevealDeadline: start + 120,
            selectedAcceptanceWindow: uint64(bound(cfgSeed, 30, 90)),
            checkpointWindow: uint64(bound(cfgSeed >> 8, 0, 30)),
            finalistCount: uint8(bound(cfgSeed >> 16, 1, 2)),
            minValidatorReveals: 1,
            maxValidatorRevealsPerFinalist: uint8(bound(cfgSeed >> 24, 1, 3)),
            historicalWeightBps: 3000,
            trialWeightBps: 7000,
            minReputation: 0,
            applicationStake: bound(cfgSeed >> 32, 0.1 ether, 1 ether),
            finalistStakeTotal: bound(cfgSeed >> 64, 0.2 ether, 2 ether),
            stipendPerFinalist: bound(cfgSeed >> 96, 0.1 ether, 1 ether),
            validatorRewardPerReveal: bound(cfgSeed >> 128, 0.05 ether, 0.5 ether),
            validatorScoreBond: bound(cfgSeed >> 160, 0.05 ether, 0.5 ether)
        });
        if (proc.finalistStakeTotal < proc.applicationStake) proc.finalistStakeTotal = proc.applicationStake;
        vm.prank(employer);
        try discovery.createPremiumJobWithDiscovery(premium, proc) {} catch {}
    }

    function applyManagerJob(uint256 jobSeed, uint256 agentSeed) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        address agent = agents[bound(agentSeed, 0, agents.length - 1)];
        vm.prank(agent);
        try manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0)) {
            if (!snapshotTaken[jobId]) {
                snapshotTaken[jobId] = true;
                snapshotFingerprint[jobId] = this.jobSnapshot(jobId);
            }
        } catch {}
    }

    function submitCheckpoint(uint256 jobSeed, uint256 agentSeed) external {
        if (manager.nextJobId() == 0) return;
        vm.prank(agents[bound(agentSeed, 0, agents.length - 1)]);
        try manager.submitCheckpoint(bound(jobSeed, 0, manager.nextJobId() - 1), "ipfs://cp") {} catch {}
    }

    function failCheckpoint(uint256 jobSeed) external {
        if (manager.nextJobId() == 0) return;
        try manager.failCheckpoint(bound(jobSeed, 0, manager.nextJobId() - 1)) {} catch {}
    }

    function requestCompletion(uint256 jobSeed, uint256 agentSeed) external {
        if (manager.nextJobId() == 0) return;
        vm.prank(agents[bound(agentSeed, 0, agents.length - 1)]);
        try manager.requestJobCompletion(bound(jobSeed, 0, manager.nextJobId() - 1), "ipfs://done") {} catch {}
    }

    function vote(uint256 jobSeed, uint256 validatorSeed, bool approveVote) external {
        if (manager.nextJobId() == 0) return;
        vm.prank(validators[bound(validatorSeed, 0, validators.length - 1)]);
        if (approveVote) {
            try manager.validateJob(bound(jobSeed, 0, manager.nextJobId() - 1), "", new bytes32[](0)) {} catch {}
        } else {
            try manager.disapproveJob(bound(jobSeed, 0, manager.nextJobId() - 1), "", new bytes32[](0)) {} catch {}
        }
    }

    function dispute(uint256 jobSeed, bool employerSide) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        (,,,,, address employer, address assignedAgent,) = manager.jobAccounting(jobId);
        address actor = employerSide ? employer : assignedAgent;
        if (actor == address(0)) return;
        vm.prank(actor);
        try manager.disputeJob(jobId) {} catch {}
    }

    function resolveDispute(uint256 jobSeed, uint8 code, bool stale, bool employerWins) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (stale) {
            vm.prank(owner);
            try manager.resolveStaleDispute(jobId, employerWins) {} catch {}
        } else {
            vm.prank(moderator);
            try manager.resolveDisputeWithCode(jobId, uint8(bound(code, 1, 4)), "mod") {} catch {}
        }
    }

    function finalizeOrExpire(uint256 jobSeed, bool finalizeJob_) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (finalizeJob_) {
            try manager.finalizeJob(jobId) {} catch {}
        } else {
            try manager.expireJob(jobId) {} catch {}
        }
    }

    function commitApplication(uint256 procurementSeed, uint256 agentSeed, uint256 saltSeed) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address agent = agents[bound(agentSeed, 0, agents.length - 1)];
        bytes32 salt = bytes32(saltSeed);
        bytes32 commitment = keccak256(abi.encodePacked(pid, agent, "ipfs://app", salt));
        vm.prank(agent);
        try discovery.commitApplication(pid, commitment, "", new bytes32[](0)) {} catch {}
    }

    function revealApplication(uint256 procurementSeed, uint256 agentSeed, uint256 saltSeed) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        vm.prank(agents[bound(agentSeed, 0, agents.length - 1)]);
        try discovery.revealApplication(pid, "", new bytes32[](0), bytes32(saltSeed), "ipfs://app") {} catch {}
    }

    function advanceProcurement(uint256 procurementSeed, uint256 actorSeed) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(actor);
        try discovery.advanceProcurement(pid) {} catch {}
    }

    function acceptOrTrial(uint256 procurementSeed, uint256 agentSeed, bool submitTrial_) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address agent = agents[bound(agentSeed, 0, agents.length - 1)];
        vm.prank(agent);
        if (submitTrial_) {
            try discovery.submitTrial(pid, "ipfs://trial") {} catch {}
        } else {
            try discovery.acceptFinalist(pid) {} catch {}
        }
    }

    function commitOrRevealScore(
        uint256 procurementSeed,
        uint256 finalistSeed,
        uint256 validatorSeed,
        uint8 score,
        uint256 saltSeed,
        bool reveal_
    ) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address finalist = agents[bound(finalistSeed, 0, agents.length - 1)];
        address validator = validators[bound(validatorSeed, 0, validators.length - 1)];
        bytes32 salt = bytes32(saltSeed);
        uint8 boundedScore = uint8(bound(score, 0, 100));
        vm.prank(validator);
        if (reveal_) {
            try discovery.revealFinalistScore(pid, finalist, boundedScore, salt, "", new bytes32[](0)) {} catch {}
        } else {
            bytes32 commitment = keccak256(abi.encodePacked(pid, finalist, validator, boundedScore, salt));
            try discovery.commitFinalistScore(pid, finalist, commitment, "", new bytes32[](0)) {} catch {}
        }
    }

    function finalizeCancelClaimOrPromote(uint256 procurementSeed, uint256 actorSeed, uint8 mode) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(actor);
        if (mode % 4 == 0) {
            try discovery.finalizeWinner(pid) {} catch {}
        } else if (mode % 4 == 1) {
            try discovery.cancelProcurement(pid) {} catch {}
        } else if (mode % 4 == 2) {
            try discovery.promoteFallbackFinalist(pid) {} catch {}
        } else {
            try discovery.claim() {} catch {}
        }
    }

    function jobSnapshot(uint256 jobId) external view returns (uint256) {
        (
            uint64 completionReview,
            uint64 disputeReview,
            uint64 challengePeriod,
            uint256 quorum,
            uint256 approvals,
            uint256 disapprovals,
            uint256 slashBps,
            uint8 payoutPct,
            uint8 validatorRewardPct
        ) = manager.jobSnapshots(jobId);
        return uint256(completionReview) + uint256(disputeReview) + uint256(challengePeriod) + quorum + approvals
            + disapprovals + slashBps + payoutPct + validatorRewardPct;
    }
}

contract PrimeProtocolInvariants is StdInvariant, Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    PrimeProtocolHandler internal handler;

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
        handler = new PrimeProtocolHandler(manager, discovery, token);
        targetContract(address(handler));
    }

    function invariant_managerSolvencyAndStateMachineFlags() external view {
        uint256 totalLocked = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedDisputeBonds()
            + manager.lockedValidatorBonds();
        assertGe(token.balanceOf(address(manager)), totalLocked, "manager insolvent");

        uint256 nextJobId = manager.nextJobId();
        for (uint256 jobId = 0; jobId < nextJobId; ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (bool completed, bool completionRequested, bool disputed, bool expired,, bool validatorApproved) =
                manager.jobFlags(jobId);
            (,,,, uint256 validatorCount,, address assignedAgent,) = manager.jobAccounting(jobId);
            (uint256 approvals, uint256 disapprovals, uint256 validatorsLength) =
                manager.jobValidatorParticipation(jobId);
            assertFalse(completed && expired, "job cannot be completed and expired");
            assertFalse(completed && disputed, "job cannot be completed while disputed");
            if (validatorApproved) assertTrue(completionRequested, "approval requires completion request");
            if (disputed) assertTrue(completionRequested, "dispute requires completion request");
            assertEq(validatorsLength, approvals + disapprovals, "vote count drift");
            assertEq(validatorCount, validatorsLength, "validator list drift");
            if (assignedAgent != address(0) && !completed && !expired) {
                assertGt(manager.activeJobsByAgentView(assignedAgent), 0, "activeJobsByAgent drift");
            }
            if (handler.snapshotTaken(jobId)) {
                assertEq(handler.snapshotFingerprint(jobId), handler.jobSnapshot(jobId), "live snapshot mutated");
            }
        }
        manager.withdrawableAGI();
    }

    function invariant_managerLockedBucketsMatchJobs() external view {
        uint256 nextJobId = manager.nextJobId();
        uint256 escrow;
        uint256 agentBonds;
        uint256 disputeBonds;
        uint256 validatorBonds;
        for (uint256 jobId = 0; jobId < nextJobId; ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (,,,, bool escrowReleased,) = manager.jobFlags(jobId);
            (
                uint256 payout,
                uint256 agentBondAmount,
                uint256 disputeBondAmount,
                uint256 validatorBondAmount,
                uint256 validatorCount,,,
            ) = manager.jobAccounting(jobId);
            if (!escrowReleased) escrow += payout;
            agentBonds += agentBondAmount;
            disputeBonds += disputeBondAmount;
            if (validatorCount > 0 && validatorBondAmount > 0) {
                validatorBonds += (validatorBondAmount - 1) * validatorCount;
            }
        }
        assertEq(manager.lockedEscrow(), escrow, "escrow accounting drift");
        assertEq(manager.lockedAgentBonds(), agentBonds, "agent bond drift");
        assertEq(manager.lockedDisputeBonds(), disputeBonds, "dispute bond drift");
        assertEq(manager.lockedValidatorBonds(), validatorBonds, "validator bond drift");
    }

    function invariant_discoverySolvency() external view {
        uint256 nextProcurementId = discovery.nextProcurementId();
        uint256 lockedDiscovery;
        for (uint256 pid = 0; pid < nextProcurementId; ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            (
                address employer,
                uint256 jobId,,
                bool winnerFinalized,
                bool cancelled,,,,,,,,
                uint8 finalistCount,,
                uint8 maxReveals,
                uint256 applicationStake,
                uint256 finalistStakeTotal,
                uint256 stipendPerFinalist,
                uint256 validatorRewardPerReveal,,
            ) = discovery.procurementView(pid);
            assertTrue(employer != address(0), "missing employer");
            assertEq(discovery.procurementByJobId(jobId), pid, "job linkage drift");
            assertTrue(discovery.hasProcurementByJobId(jobId), "job linkage flag missing");
            assertLe(applicationStake, finalistStakeTotal, "stake inversion");

            uint256 budgetCap = uint256(finalistCount) * stipendPerFinalist + uint256(finalistCount)
                * uint256(maxReveals) * validatorRewardPerReveal;
            if (!winnerFinalized && !cancelled) lockedDiscovery += budgetCap;

            address[] memory applicants = discovery.procurementApplicants(pid);
            address[] memory finalists = discovery.procurementFinalists(pid);
            assertLe(finalists.length, finalistCount, "too many finalists");

            for (uint256 i = 0; i < applicants.length; ++i) {
                (,,,, uint256 lockedStake,,,,,,) = discovery.applicationView(pid, applicants[i]);
                lockedDiscovery += lockedStake;
            }
            for (uint256 i = 0; i < finalists.length; ++i) {
                assertLe(discovery.revealedScoreCount(pid, finalists[i]), maxReveals, "too many reveals per finalist");
                for (uint256 v = 0; v < 3; ++v) {
                    (, bool revealedScore,, uint256 bond) =
                        discovery.scoreCommitView(pid, finalists[i], address(uint160(0x3000 + v)));
                    if (winnerFinalized || cancelled) {
                        if (!revealedScore) assertEq(bond, 0, "terminal state stranded unrevealed validator bond");
                    }
                    lockedDiscovery += bond;
                }
            }
        }

        uint256 claimableTotal;
        address[] memory actors = handler.actorsView();
        for (uint256 i = 0; i < actors.length; ++i) {
            claimableTotal += discovery.claimable(actors[i]);
        }
        assertGe(token.balanceOf(address(discovery)), lockedDiscovery + claimableTotal, "discovery insolvent");
    }

    function invariant_discoveryStateMachineAndHelperTruth() external view {
        uint256 nextProcurementId = discovery.nextProcurementId();
        for (uint256 pid = 0; pid < nextProcurementId; ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            (
                address employer,
                uint256 jobId,
                bool shortlistFinalized,
                bool winnerFinalized,
                bool cancelled,,,,,,,,
                uint8 finalistCount,,
                uint8 maxReveals,
                uint256 applicationStake,
                uint256 finalistStakeTotal,
                uint256 stipendPerFinalist,
                uint256 validatorRewardPerReveal,,
            ) = discovery.procurementView(pid);
            assertTrue(employer != address(0), "missing employer");
            assertEq(discovery.procurementByJobId(jobId), pid, "job linkage drift");
            assertTrue(discovery.hasProcurementByJobId(jobId), "job linkage flag missing");
            if (cancelled) assertFalse(winnerFinalized, "cancelled procurement finalized later");
            assertLe(applicationStake, finalistStakeTotal, "stake inversion");

            address[] memory applicants = discovery.procurementApplicants(pid);
            address[] memory finalists = discovery.procurementFinalists(pid);
            assertLe(finalists.length, finalistCount, "too many finalists");
            for (uint256 i = 0; i < applicants.length; ++i) {
                (
                    bool revealed,
                    bool shortlisted,
                    bool finalistAccepted,
                    bool trialSubmitted,,,,,,
                    uint256 compositeScoreBps,
                    bool everPromoted
                ) = discovery.applicationView(pid, applicants[i]);
                if (shortlisted) assertTrue(revealed, "shortlisted => revealed broken");
                if (finalistAccepted) assertTrue(shortlisted, "accepted finalist must be shortlisted");
                if (trialSubmitted) assertTrue(finalistAccepted, "trial requires acceptance");
                if (everPromoted) assertTrue(shortlisted, "promotion requires shortlist");
                if (compositeScoreBps > 0) {
                    assertTrue(shortlisted, "composite requires shortlist");
                    assertTrue(finalistAccepted, "composite requires finalist acceptance");
                    assertTrue(trialSubmitted, "composite requires submitted trial");
                }
            }

            uint256 budgetCap = uint256(finalistCount) * stipendPerFinalist + uint256(finalistCount)
                * uint256(maxReveals) * validatorRewardPerReveal;
            assertGe(budgetCap, uint256(finalists.length) * validatorRewardPerReveal, "reward cap incoherent");
            if (shortlistFinalized && !winnerFinalized && !cancelled) {
                string memory action = discovery.nextActionForProcurement(pid);
                if (keccak256(bytes(action)) == keccak256(bytes("FW"))) {
                    assertTrue(discovery.isWinnerFinalizable(pid), "FW helper lied");
                }
            }
        }
    }

    function invariant_helperViewsAndNFTGating() external view {
        uint256 nextProcurementId = discovery.nextProcurementId();
        for (uint256 pid = 0; pid < nextProcurementId; ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            string memory action = discovery.nextActionForProcurement(pid);
            if (keccak256(bytes(action)) == keccak256(bytes("FS"))) {
                assertTrue(discovery.isShortlistFinalizable(pid), "FS helper lied");
            }
            if (discovery.isFallbackPromotable(pid)) {
                assertEq(keccak256(bytes(action)), keccak256(bytes("PF")), "fallback helper mismatch");
            }
        }
        assertEq(address(manager.completionNFT()).code.length > 0, true, "completion NFT missing");
    }
}
