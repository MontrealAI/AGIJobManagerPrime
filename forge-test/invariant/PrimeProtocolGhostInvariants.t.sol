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

contract PrimeGhostHandler is Test {
    struct JobGhost {
        bool snapshotTaken;
        uint256 snapshotFingerprint;
    }

    AGIJobManagerPrimeHarness public manager;
    AGIJobDiscoveryPrimeHarness public discovery;
    MockERC20 public token;
    address public owner;
    address public moderator;
    address[] public actors;
    address[] public agents;
    address[] public validators;
    mapping(uint256 => JobGhost) public jobs;
    mapping(address => uint256) public lastClaimable;
    mapping(address => uint256) public totalClaimedByActor;

    uint256 internal constant MAX_MANAGER_JOBS = 24;
    uint256 internal constant MAX_DISCOVERY_PROCUREMENTS = 24;

    constructor(AGIJobManagerPrimeHarness _manager, AGIJobDiscoveryPrimeHarness _discovery, MockERC20 _token) {
        manager = _manager;
        discovery = _discovery;
        token = _token;
        owner = manager.owner();
        moderator = address(0xBEEF);
        MockERC721 agiType = new MockERC721();
        MockENSJobPages pages = new MockENSJobPages();
        MockENSJobPagesMalformed malformed = new MockENSJobPagesMalformed();
        malformed.setRevertOnHook(true);
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
        for (uint256 i = 0; i < 4; ++i) {
            address employer = address(uint160(0x1000 + i));
            address agent = address(uint160(0x2000 + i));
            address validator = address(uint160(0x3000 + i));
            actors.push(employer);
            actors.push(agent);
            actors.push(validator);
            agents.push(agent);
            validators.push(validator);
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
        _refreshClaims();
    }

    function actorsView() external view returns (address[] memory) {
        return actors;
    }

    function _refreshClaims() internal {
        for (uint256 i = 0; i < actors.length; ++i) {
            address actor = actors[i];
            uint256 current = discovery.claimable(actor);
            if (current < lastClaimable[actor]) totalClaimedByActor[actor] += lastClaimable[actor] - current;
            lastClaimable[actor] = current;
        }
    }

    function _fingerprint(uint256 jobId) internal view returns (uint256) {
        (uint64 a, uint64 b, uint64 c, uint256 d, uint256 e, uint256 f, uint256 g, uint8 h, uint8 i) =
            manager.jobSnapshots(jobId);
        return uint256(a) + uint256(b) + uint256(c) + d + e + f + g + h + i;
    }

    function _captureJob(uint256 jobId) internal {
        if (!manager.jobExists(jobId)) return;
        JobGhost storage g = jobs[jobId];
        (,,,,,, address assignedAgent,) = manager.jobAccounting(jobId);
        if (!g.snapshotTaken && assignedAgent != address(0)) {
            g.snapshotTaken = true;
            g.snapshotFingerprint = _fingerprint(jobId);
        }
    }

    function warp(uint256 seed) external {
        vm.warp(block.timestamp + bound(seed, 1, 30 days));
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
        _refreshClaims();
    }

    function createManagerJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed, bool selectedOnly)
        external
    {
        if (manager.nextJobId() >= MAX_MANAGER_JOBS) return;
        address employer = actors[bound(employerSeed, 0, 3) * 3];
        vm.prank(employer);
        try manager.createConfiguredJob(
            "ipfs://job",
            bound(payoutSeed, 1 ether, 50 ether),
            bound(durationSeed, 1 hours, 7 days),
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
                try manager.designateSelectedAgent(jobId, agents[jobId % agents.length], 1 days, 0) {} catch {}
            }
            _captureJob(jobId);
        } catch {}
        _refreshClaims();
    }

    function managerAction(uint256 jobSeed, uint256 actorSeed, uint8 mode) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        (,,,,, address employer, address assignedAgent,) = manager.jobAccounting(jobId);
        address actor;

        if (mode % 7 == 0) {
            actor = agents[bound(actorSeed, 0, agents.length - 1)];
        } else if (mode % 7 == 1) {
            actor = assignedAgent == address(0) ? agents[bound(actorSeed, 0, agents.length - 1)] : assignedAgent;
        } else if (mode % 7 == 2 || mode % 7 == 3) {
            actor = validators[bound(actorSeed, 0, validators.length - 1)];
        } else if (mode % 7 == 4) {
            if (assignedAgent != address(0) && (actorSeed & 1) == 1) actor = assignedAgent;
            else actor = employer;
        } else {
            actor = actors[bound(actorSeed, 0, actors.length - 1)];
        }

        vm.prank(actor);
        if (mode % 7 == 0) {
            try manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0)) {} catch {}
        } else if (mode % 7 == 1) {
            try manager.requestJobCompletion(jobId, "ipfs://done") {} catch {}
        } else if (mode % 7 == 2) {
            try manager.validateJob(jobId, "", new bytes32[](0)) {} catch {}
        } else if (mode % 7 == 3) {
            try manager.disapproveJob(jobId, "", new bytes32[](0)) {} catch {}
        } else if (mode % 7 == 4) {
            try manager.disputeJob(jobId) {} catch {}
        } else if (mode % 7 == 5) {
            try manager.finalizeJob(jobId) {} catch {}
        } else {
            try manager.expireJob(jobId) {} catch {}
        }
        _captureJob(jobId);
        _refreshClaims();
    }

    function moderatorAction(uint256 jobSeed, bool stale, bool employerWins) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (stale) {
            vm.prank(owner);
            try manager.resolveStaleDispute(jobId, employerWins) {} catch {}
        } else {
            vm.prank(moderator);
            try manager.resolveDisputeWithCode(jobId, employerWins ? 2 : 1, "mod") {} catch {}
        }
        _captureJob(jobId);
        _refreshClaims();
    }

    function createDiscoveryJob(uint256 employerSeed) external {
        if (discovery.nextProcurementId() >= MAX_DISCOVERY_PROCUREMENTS || manager.nextJobId() >= MAX_MANAGER_JOBS) {
            return;
        }
        uint64 start = uint64(block.timestamp + 10);
        address employer = actors[bound(employerSeed, 0, 3) * 3];
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
            validatorRewardPerReveal: 0.1 ether,
            validatorScoreBond: 0.5 ether
        });
        vm.prank(employer);
        try discovery.createPremiumJobWithDiscovery(premium, proc) {} catch {}
        _refreshClaims();
    }

    function discoveryAction(uint256 procurementSeed, uint256 actorSeed, uint8 score, uint8 mode) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address actor;
        address finalist;

        address[] memory finalists = discovery.procurementFinalists(pid);
        if (finalists.length > 0) {
            finalist = finalists[bound(actorSeed, 0, finalists.length - 1)];
        } else {
            finalist = agents[bound(actorSeed, 0, agents.length - 1)];
        }

        if (mode % 8 <= 1 || mode % 8 == 3 || mode % 8 == 4) {
            actor = agents[bound(actorSeed, 0, agents.length - 1)];
        } else if (mode % 8 == 5 || mode % 8 == 6) {
            actor = validators[bound(actorSeed, 0, validators.length - 1)];
        } else {
            actor = actors[bound(actorSeed, 0, actors.length - 1)];
        }

        bytes32 salt = keccak256(abi.encodePacked(pid, actor, finalist));
        if (mode % 8 == 0) {
            vm.prank(actor);
            try discovery.commitApplication(
                pid, keccak256(abi.encodePacked(pid, actor, "ipfs://app", salt)), "", new bytes32[](0)
            ) {}
                catch {}
        } else if (mode % 8 == 1) {
            vm.prank(actor);
            try discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app") {} catch {}
        } else if (mode % 8 == 2) {
            vm.prank(actor);
            try discovery.finalizeShortlist(pid) {} catch {}
        } else if (mode % 8 == 3) {
            vm.prank(actor);
            try discovery.acceptFinalist(pid) {} catch {}
        } else if (mode % 8 == 4) {
            vm.prank(actor);
            try discovery.submitTrial(pid, "ipfs://trial") {} catch {}
        } else if (mode % 8 == 5) {
            vm.prank(actor);
            try discovery.commitFinalistScore(
                pid,
                finalist,
                keccak256(abi.encodePacked(pid, finalist, actor, uint8(bound(score, 0, 100)), salt)),
                "",
                new bytes32[](0)
            ) {}
                catch {}
        } else if (mode % 8 == 6) {
            vm.prank(actor);
            try discovery.revealFinalistScore(pid, finalist, uint8(bound(score, 0, 100)), salt, "", new bytes32[](0)) {}
                catch {}
        } else {
            vm.prank(actor);
            try discovery.finalizeWinner(pid) {} catch {}
        }
        _refreshClaims();
    }

    function cancelOrClaim(uint256 procurementSeed, uint256 actorSeed, bool cancel_) external {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(actor);
        if (cancel_ && discovery.nextProcurementId() > 0) {
            try discovery.cancelProcurement(bound(procurementSeed, 0, discovery.nextProcurementId() - 1)) {} catch {}
        } else {
            try discovery.claim() {} catch {}
        }
        _refreshClaims();
    }
}

contract PrimeProtocolGhostInvariants is StdInvariant, Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    PrimeGhostHandler internal handler;

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
        handler = new PrimeGhostHandler(manager, discovery, token);
        targetContract(address(handler));
    }

    function _fingerprint(uint256 jobId) internal view returns (uint256) {
        (uint64 a, uint64 b, uint64 c, uint256 d, uint256 e, uint256 f, uint256 g, uint8 h, uint8 i) =
            manager.jobSnapshots(jobId);
        return uint256(a) + uint256(b) + uint256(c) + d + e + f + g + h + i;
    }

    function invariant_managerAccountingAndGhostSnapshots() external view {
        uint256 locked = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), locked, "manager insolvent");
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (bool completed, bool completionRequested, bool disputed, bool expired,, bool validatorApproved) =
                manager.jobFlags(jobId);
            (
                uint256 payout,
                uint256 agentBondAmount,
                uint256 disputeBondAmount,
                uint256 validatorBondAmount,
                uint256 validatorCount,,
                address assignedAgent,
            ) = manager.jobAccounting(jobId);
            (uint256 approvals, uint256 disapprovals, uint256 validatorsLength) =
                manager.jobValidatorParticipation(jobId);
            assertFalse(completed && expired, "completed and expired");
            assertFalse(completed && disputed, "completed and disputed");
            assertEq(validatorsLength, approvals + disapprovals, "vote drift");
            if (validatorApproved) assertTrue(completionRequested, "approval without completion request");
            if (assignedAgent != address(0) && !completed && !expired) {
                assertGt(manager.activeJobsByAgentView(assignedAgent), 0, "active job drift");
            }
            (bool snapshotTaken, uint256 snapshotFingerprint) = handler.jobs(jobId);
            if (snapshotTaken) assertEq(snapshotFingerprint, _fingerprint(jobId), "snapshot mutated");
            assertLe(agentBondAmount, payout, "agent bond > payout");
            assertLe(disputeBondAmount, payout, "dispute bond > payout");
            if (validatorCount > 0 && validatorBondAmount > 0) {
                assertLe(validatorBondAmount - 1, payout, "validator bond > payout");
            }
        }
    }

    function invariant_discoveryAccountingAndStateMachine() external view {
        uint256 lockedDiscovery;
        uint256 claimableTotal;
        address[] memory actors = handler.actorsView();
        for (uint256 i = 0; i < actors.length; ++i) {
            claimableTotal += discovery.claimable(actors[i]);
        }
        for (uint256 pid = 0; pid < discovery.nextProcurementId(); ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            (
                address employer,
                uint256 jobId,
                bool shortlistFinalized,
                bool winnerFinalized,
                bool cancelled,
                uint64 pauseBaseline,,,,,,,
                uint8 finalistCount,
                uint8 minValidatorReveals,
                uint8 maxValidatorReveals,
                uint256 applicationStake,
                uint256 finalistStakeTotal,
                uint256 stipendPerFinalist,
                uint256 validatorRewardPerReveal,,
            ) = discovery.procurementView(pid);
            employer;
            pauseBaseline;
            assertEq(discovery.procurementByJobId(jobId), pid, "job linkage drift");
            assertTrue(discovery.hasProcurementByJobId(jobId), "missing linkage flag");
            assertFalse(cancelled && winnerFinalized, "cancelled finalized contradiction");
            assertLe(applicationStake, finalistStakeTotal, "application stake > finalist stake");
            assertGe(maxValidatorReveals, minValidatorReveals, "max reveals < min reveals");
            address[] memory applicants = discovery.procurementApplicants(pid);
            address[] memory finalists = discovery.procurementFinalists(pid);
            assertLe(finalists.length, finalistCount, "too many finalists");
            for (uint256 i = 0; i < applicants.length; ++i) {
                (
                    bool revealed,
                    bool shortlisted,
                    bool finalistAccepted,
                    bool trialSubmitted,
                    uint256 lockedStake,,,,,,
                    bool everPromoted
                ) = discovery.applicationView(pid, applicants[i]);
                if (shortlisted) assertTrue(revealed, "shortlisted => revealed");
                if (finalistAccepted) assertTrue(shortlisted, "accepted => shortlisted");
                if (trialSubmitted) assertTrue(finalistAccepted, "trial => accepted");
                if (everPromoted) assertTrue(shortlisted, "promoted => shortlisted");
                lockedDiscovery += lockedStake;
            }
            for (uint256 i = 0; i < finalists.length; ++i) {
                assertLe(discovery.revealedScoreCount(pid, finalists[i]), maxValidatorReveals, "score reveal cap drift");
                for (uint256 v = 0; v < 4; ++v) {
                    (, bool revealedScore,, uint256 bond) =
                        discovery.scoreCommitView(pid, finalists[i], address(uint160(0x3000 + v)));
                    if ((winnerFinalized || cancelled) && !revealedScore) assertEq(bond, 0, "stranded validator bond");
                    lockedDiscovery += bond;
                }
            }
            if (!winnerFinalized && !cancelled) {
                lockedDiscovery += uint256(finalistCount) * stipendPerFinalist + uint256(finalistCount)
                * uint256(maxValidatorReveals) * validatorRewardPerReveal;
            }
            if (shortlistFinalized && !winnerFinalized && !cancelled) {
                assertTrue(bytes(discovery.nextActionForProcurement(pid)).length > 0, "next action missing");
            }
        }
        assertGe(token.balanceOf(address(discovery)), lockedDiscovery + claimableTotal, "discovery insolvent");
    }

    function invariant_claimableAndCompletionNFTGating() external view {
        uint256 currentClaimable;
        address[] memory actors = handler.actorsView();
        for (uint256 i = 0; i < actors.length; ++i) {
            currentClaimable += discovery.claimable(actors[i]);
        }
        assertLe(currentClaimable, token.balanceOf(address(discovery)), "claimable exceeds balance");
        uint256 completedJobs;
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (bool completed,,,,,) = manager.jobFlags(jobId);
            if (completed) completedJobs += 1;
        }
        assertLe(manager.completionNFT().nextTokenId(), completedJobs, "completion NFT without completion");
    }
}
