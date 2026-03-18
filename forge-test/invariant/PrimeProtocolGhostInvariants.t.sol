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
import "contracts/test/HookGasBurner.sol";
import "contracts/utils/BusinessOwnable2Step.sol";

contract PrimeGhostHandler is Test {
    struct JobGhost {
        bool snapshotTaken;
        uint256 snapshotFingerprint;
        bool completedSeen;
        bool expiredSeen;
        bool disputedSeen;
        bool disputeResolvedSeen;
        uint256 completionTransitions;
        uint256 expiryTransitions;
        uint256 disputeOpenTransitions;
        uint256 disputeResolutionTransitions;
    }

    struct ProcurementGhost {
        bool winnerSeen;
        bool cancelledSeen;
        uint256 winnerTransitions;
        uint256 cancelTransitions;
        uint256 fallbackPromotions;
        uint64 pauseBaseline;
    }

    AGIJobManagerPrimeHarness public manager;
    AGIJobDiscoveryPrimeHarness public discovery;
    MockERC20 public token;
    address public owner;
    address public moderator;

    address[] public employers;
    address[] public agents;
    address[] public validators;
    address[] public actors;

    MockENSJobPages public healthyHook;
    MockENSJobPagesMalformed public malformedHook;
    HookGasBurner public gasBurnerHook;

    mapping(uint256 => JobGhost) public jobs;
    mapping(uint256 => ProcurementGhost) public procurements;
    mapping(address => uint256) public lastClaimable;
    mapping(address => uint256) public totalClaimedByActor;
    mapping(uint256 => mapping(address => bool)) public applicationSettledSeen;
    mapping(uint256 => mapping(address => bool)) public finalistEverPromotedSeen;
    mapping(uint256 => mapping(address => mapping(address => bool))) public scoreSettledSeen;

    uint256 public expectedManagerLockedEscrow;
    uint256 public expectedManagerLockedAgentBonds;
    uint256 public expectedManagerLockedValidatorBonds;
    uint256 public expectedManagerLockedDisputeBonds;

    uint256 public expectedDiscoveryLockedApplicationStakes;
    uint256 public expectedDiscoveryLockedFinalistStakes;
    uint256 public expectedDiscoveryLockedScoreBonds;
    uint256 public expectedDiscoveryBudgetReservations;
    uint256 public expectedDiscoveryClaimable;

    uint256 public observedClaimablePaidOut;
    uint256 public completionNFTObservation;

    uint256 internal constant MAX_MANAGER_JOBS = 32;
    uint256 internal constant MAX_DISCOVERY_PROCUREMENTS = 32;

    constructor(AGIJobManagerPrimeHarness _manager, AGIJobDiscoveryPrimeHarness _discovery, MockERC20 _token) {
        manager = _manager;
        discovery = _discovery;
        token = _token;
        owner = manager.owner();
        moderator = address(0xBEEF);

        MockERC721 agiType = new MockERC721();
        healthyHook = new MockENSJobPages();
        malformedHook = new MockENSJobPagesMalformed();
        gasBurnerHook = new HookGasBurner();

        vm.startPrank(owner);
        manager.setDiscoveryModule(address(discovery));
        manager.addModerator(moderator);
        manager.addOrUpdateAGIType(address(agiType), 80);
        manager.setRequiredValidatorApprovals(1);
        manager.setRequiredValidatorDisapprovals(1);
        manager.setVoteQuorum(1);
        manager.setPremiumReputationThreshold(0);
        manager.setChallengePeriodAfterApproval(1 days);
        manager.setEnsJobPages(address(healthyHook));
        vm.stopPrank();

        for (uint256 i = 0; i < 4; ++i) {
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

        malformedHook.setTokenURIBytes(hex"00");
        _syncGhostState();
    }

    function actorsView() external view returns (address[] memory) {
        return actors;
    }

    function _fingerprint(uint256 jobId) internal view returns (uint256) {
        (uint64 a, uint64 b, uint64 c, uint256 d, uint256 e, uint256 f, uint256 g, uint8 h, uint8 i) =
            manager.jobSnapshots(jobId);
        return uint256(a) + uint256(b) + uint256(c) + d + e + f + g + h + i;
    }

    function _boundWarp(uint256 seed) internal {
        uint256 dt = bound(seed, 0, 10);
        if (dt == 0) vm.warp(block.timestamp + 1);
        else if (dt == 1) vm.warp(block.timestamp + 59);
        else if (dt == 2) vm.warp(block.timestamp + 1 days - 1);
        else if (dt == 3) vm.warp(block.timestamp + 1 days);
        else if (dt == 4) vm.warp(block.timestamp + 1 days + 1);
        else if (dt == 5) vm.warp(block.timestamp + 7 days);
        else if (dt == 6) vm.warp(block.timestamp + 14 days);
        else if (dt == 7) vm.warp(block.timestamp + 30 days);
        else if (dt == 8) vm.warp(block.timestamp + 45 days);
        else if (dt == 9) vm.warp(block.timestamp + 90 days);
        else vm.warp(block.timestamp + 180 days);
    }

    function warp(uint256 seed) external {
        _boundWarp(seed);
        _syncGhostState();
    }

    function adminAction(uint256 seed) external {
        uint256 mode = seed % 11;
        if (mode <= 7) vm.startPrank(owner);
        if (mode == 0) {
            manager.pause();
        } else if (mode == 1) {
            manager.unpause();
        } else if (mode == 2) {
            manager.setSettlementPaused((seed & 1) == 1);
        } else if (mode == 3) {
            if ((seed & 1) == 1) discovery.pause();
            else if (discovery.paused()) discovery.unpause();
        } else if (mode == 4) {
            discovery.setIntakePaused((seed & 2) == 2);
        } else if (mode == 5) {
            manager.setChallengePeriodAfterApproval(bound(seed >> 8, 1 hours, 7 days));
        } else if (mode == 6) {
            manager.setPremiumReputationThreshold(bound(seed >> 16, 0, 5_000));
        } else if (mode == 7) {
            address hook = address(healthyHook);
            if ((seed & 4) == 4) hook = address(malformedHook);
            if ((seed & 8) == 8) hook = address(gasBurnerHook);
            malformedHook.setRevertOnHook((seed & 16) == 16);
            manager.setEnsJobPages(hook);
        } else if (mode == 8) {
            vm.prank(discovery.owner());
            discovery.transferOwnership(actors[bound(seed >> 24, 0, actors.length - 1)]);
        } else if (mode == 9) {
            address pending = discovery.pendingOwner();
            if (pending != address(0)) {
                vm.prank(pending);
                try discovery.acceptOwnership() {} catch {}
            }
        } else {
            vm.prank(discovery.owner());
            try discovery.cancelOwnershipTransfer() {} catch {}
        }
        if (mode <= 7) vm.stopPrank();
        _syncGhostState();
    }

    function createManagerJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed, uint8 configMode)
        external
    {
        if (manager.nextJobId() >= MAX_MANAGER_JOBS) return;
        address employer = employers[bound(employerSeed, 0, employers.length - 1)];
        uint8 mode = uint8(configMode % 3);
        AGIJobManagerPrime.IntakeMode intakeMode = AGIJobManagerPrime.IntakeMode.OpenFirstCome;
        if (mode == 1) intakeMode = AGIJobManagerPrime.IntakeMode.SelectedAgentOnly;
        if (mode == 2) intakeMode = AGIJobManagerPrime.IntakeMode.PerJobMerkleRoot;

        vm.prank(employer);
        try manager.createConfiguredJob(
            "ipfs://job",
            bound(payoutSeed, 1 ether, 80 ether),
            bound(durationSeed, 1 hours, 10 days),
            "details",
            intakeMode,
            mode == 2 ? keccak256(abi.encodePacked(employer, payoutSeed, durationSeed)) : bytes32(0)
        ) returns (
            uint256 jobId
        ) {
            if (intakeMode == AGIJobManagerPrime.IntakeMode.SelectedAgentOnly) {
                vm.prank(owner);
                try manager.designateSelectedAgent(
                    jobId,
                    agents[jobId % agents.length],
                    uint64(bound(durationSeed >> 8, 1 hours, 3 days)),
                    uint64(bound(durationSeed >> 32, 0, 2 days))
                ) {}
                    catch {}
            }
        } catch {}
        _syncGhostState();
    }

    function createOrAttachDiscoveryProcurement(
        uint256 employerSeed,
        uint256 payoutSeed,
        uint256 durationSeed,
        uint256 cfgSeed,
        bool attachExisting
    ) external {
        address employer = employers[bound(employerSeed, 0, employers.length - 1)];
        uint64 start = uint64(block.timestamp + 10);
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
            minValidatorReveals: uint8(bound(cfgSeed >> 24, 1, 2)),
            maxValidatorRevealsPerFinalist: uint8(bound(cfgSeed >> 32, 1, 3)),
            historicalWeightBps: 3000,
            trialWeightBps: 7000,
            minReputation: 0,
            applicationStake: bound(cfgSeed >> 64, 0.1 ether, 1 ether),
            finalistStakeTotal: bound(cfgSeed >> 96, 0.2 ether, 2 ether),
            stipendPerFinalist: bound(cfgSeed >> 128, 0.1 ether, 1 ether),
            validatorRewardPerReveal: bound(cfgSeed >> 160, 0.05 ether, 0.5 ether),
            validatorScoreBond: bound(cfgSeed >> 192, 0.05 ether, 0.5 ether)
        });
        if (proc.maxValidatorRevealsPerFinalist < proc.minValidatorReveals) {
            proc.maxValidatorRevealsPerFinalist = proc.minValidatorReveals;
        }
        if (proc.finalistStakeTotal < proc.applicationStake) proc.finalistStakeTotal = proc.applicationStake;

        vm.prank(employer);
        if (attachExisting && manager.nextJobId() > 0) {
            uint256 jobId = bound(cfgSeed >> 224, 0, manager.nextJobId() - 1);
            try discovery.attachProcurementToExistingJob(jobId, proc) {} catch {}
        } else if (discovery.nextProcurementId() < MAX_DISCOVERY_PROCUREMENTS && manager.nextJobId() < MAX_MANAGER_JOBS)
        {
            AGIJobDiscoveryPrime.PremiumJobParams memory premium = AGIJobDiscoveryPrime.PremiumJobParams({
                jobSpecURI: "ipfs://prime",
                payout: bound(payoutSeed, 5 ether, 60 ether),
                duration: bound(durationSeed, 1 days, 7 days),
                details: "prime"
            });
            try discovery.createPremiumJobWithDiscovery(premium, proc) {} catch {}
        }
        _syncGhostState();
    }

    function managerAction(uint256 jobSeed, uint256 actorSeed, uint8 mode) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        (,,,,, address employer, address assignedAgent, address selectedAgent) = manager.jobAccounting(jobId);
        address actor;
        uint8 action = uint8(mode % 11);
        if (action == 0) {
            actor = agents[bound(actorSeed, 0, agents.length - 1)];
        } else if (action == 1 || action == 2) {
            actor = assignedAgent == address(0) ? agents[bound(actorSeed, 0, agents.length - 1)] : assignedAgent;
        } else if (action == 3 || action == 4) {
            actor = validators[bound(actorSeed, 0, validators.length - 1)];
        } else if (action == 5 || action == 6 || action == 7) {
            actor = assignedAgent != address(0) && (actorSeed & 1) == 1 ? assignedAgent : employer;
        } else if (action == 8) {
            actor = employer;
        } else if (action == 9) {
            actor = selectedAgent == address(0) ? owner : selectedAgent;
        } else {
            actor = actors[bound(actorSeed, 0, actors.length - 1)];
        }

        vm.prank(actor);
        if (action == 0) {
            try manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0)) {} catch {}
        } else if (action == 1) {
            try manager.submitCheckpoint(jobId, "ipfs://cp") {} catch {}
        } else if (action == 2) {
            try manager.requestJobCompletion(jobId, "ipfs://done") {} catch {}
        } else if (action == 3) {
            try manager.validateJob(jobId, "", new bytes32[](0)) {} catch {}
        } else if (action == 4) {
            try manager.disapproveJob(jobId, "", new bytes32[](0)) {} catch {}
        } else if (action == 5) {
            try manager.disputeJob(jobId) {} catch {}
        } else if (action == 6) {
            try manager.finalizeJob(jobId) {} catch {}
        } else if (action == 7) {
            try manager.expireJob(jobId) {} catch {}
        } else if (action == 8) {
            try manager.cancelJob(jobId) {} catch {}
        } else if (action == 9) {
            try manager.applyForJob(jobId, "ens-agent", new bytes32[](0), new bytes32[](0)) {} catch {}
        } else {
            try manager.failCheckpoint(jobId) {} catch {}
        }
        _syncGhostState();
    }

    function moderatorAction(uint256 jobSeed, bool stale, bool employerWins, uint8 resolutionCode) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (stale) {
            vm.prank(owner);
            try manager.resolveStaleDispute(jobId, employerWins) {} catch {}
        } else {
            vm.prank(moderator);
            try manager.resolveDisputeWithCode(jobId, uint8(bound(resolutionCode, 1, 4)), "mod") {} catch {}
        }
        _syncGhostState();
    }

    function discoveryAction(uint256 procurementSeed, uint256 actorSeed, uint8 scoreSeed, uint8 mode) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address[] memory finalists = discovery.procurementFinalists(pid);
        address finalist = finalists.length == 0
            ? agents[bound(actorSeed, 0, agents.length - 1)]
            : finalists[bound(actorSeed, 0, finalists.length - 1)];
        address actor;
        uint8 action = uint8(mode % 11);
        if (action <= 1 || action == 3 || action == 4) actor = agents[bound(actorSeed, 0, agents.length - 1)];
        else if (action == 5 || action == 6) actor = validators[bound(actorSeed, 0, validators.length - 1)];
        else if (action == 7) actor = actors[bound(actorSeed, 0, actors.length - 1)];
        else if (action == 8) actor = employers[bound(actorSeed, 0, employers.length - 1)];
        else actor = actors[bound(actorSeed, 0, actors.length - 1)];

        bytes32 salt = keccak256(abi.encodePacked(pid, actor, finalist, mode));
        vm.prank(actor);
        if (action == 0) {
            try discovery.commitApplication(
                pid, keccak256(abi.encodePacked(pid, actor, "ipfs://app", salt)), "", new bytes32[](0)
            ) {}
                catch {}
        } else if (action == 1) {
            try discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app") {} catch {}
        } else if (action == 2) {
            try discovery.finalizeShortlist(pid) {} catch {}
        } else if (action == 3) {
            try discovery.acceptFinalist(pid) {} catch {}
        } else if (action == 4) {
            try discovery.submitTrial(pid, "ipfs://trial") {} catch {}
        } else if (action == 5) {
            try discovery.commitFinalistScore(
                pid,
                finalist,
                keccak256(abi.encodePacked(pid, finalist, actor, uint8(bound(scoreSeed, 0, 100)), salt)),
                "",
                new bytes32[](0)
            ) {}
                catch {}
        } else if (action == 6) {
            try discovery.revealFinalistScore(
                pid, finalist, uint8(bound(scoreSeed, 0, 100)), salt, "", new bytes32[](0)
            ) {}
                catch {}
        } else if (action == 7) {
            try discovery.finalizeWinner(pid) {} catch {}
        } else if (action == 8) {
            try discovery.cancelProcurement(pid) {} catch {}
        } else if (action == 9) {
            try discovery.promoteFallbackFinalist(pid) {} catch {}
        } else {
            try discovery.advanceProcurement(pid) {} catch {}
        }
        _syncGhostState();
    }

    function claimAction(uint256 actorSeed) external {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(actor);
        try discovery.claim() {} catch {}
        _syncGhostState();
    }

    function _syncGhostState() internal {
        uint256 managerEscrow;
        uint256 managerAgentBonds;
        uint256 managerValidatorBonds;
        uint256 managerDisputeBonds;

        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (bool completed,, bool disputed, bool expired, bool escrowReleased,) = manager.jobFlags(jobId);
            (
                uint256 payout,
                uint256 agentBondAmount,
                uint256 disputeBondAmount,
                uint256 validatorBondAmount,
                uint256 validatorCount,,
                address assignedAgent,
            ) = manager.jobAccounting(jobId);
            JobGhost storage g = jobs[jobId];
            if (!g.snapshotTaken && assignedAgent != address(0)) {
                g.snapshotTaken = true;
                g.snapshotFingerprint = _fingerprint(jobId);
            }
            if (completed && !g.completedSeen) {
                g.completedSeen = true;
                g.completionTransitions += 1;
            }
            if (expired && !g.expiredSeen) {
                g.expiredSeen = true;
                g.expiryTransitions += 1;
            }
            if (disputed && !g.disputedSeen) {
                g.disputedSeen = true;
                g.disputeOpenTransitions += 1;
            }
            if (!disputed && g.disputedSeen && !g.disputeResolvedSeen) {
                g.disputeResolvedSeen = true;
                g.disputeResolutionTransitions += 1;
            }

            if (!escrowReleased) managerEscrow += payout;
            managerAgentBonds += agentBondAmount;
            managerDisputeBonds += disputeBondAmount;
            if (validatorCount > 0 && validatorBondAmount > 0) {
                managerValidatorBonds += (validatorBondAmount - 1) * validatorCount;
            }
        }

        uint256 discoveryApplications;
        uint256 discoveryFinalists;
        uint256 discoveryScoreBonds;
        uint256 discoveryBudgets;
        uint256 claimableTotal;

        for (uint256 i = 0; i < actors.length; ++i) {
            address actor = actors[i];
            uint256 currentClaimable = discovery.claimable(actor);
            if (currentClaimable < lastClaimable[actor]) {
                uint256 delta = lastClaimable[actor] - currentClaimable;
                totalClaimedByActor[actor] += delta;
                observedClaimablePaidOut += delta;
            }
            lastClaimable[actor] = currentClaimable;
            claimableTotal += currentClaimable;
        }

        for (uint256 pid = 0; pid < discovery.nextProcurementId(); ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            (
                ,,,
                bool winnerFinalized,
                bool cancelled,
                uint64 pauseBaseline,,,,,,,
                uint8 finalistCount,,
                uint8 maxReveals,
                uint256 applicationStake,
                uint256 finalistStakeTotal,
                uint256 stipendPerFinalist,
                uint256 validatorRewardPerReveal,,
            ) = discovery.procurementView(pid);
            ProcurementGhost storage pg = procurements[pid];
            if (winnerFinalized && !pg.winnerSeen) {
                pg.winnerSeen = true;
                pg.winnerTransitions += 1;
            }
            if (cancelled && !pg.cancelledSeen) {
                pg.cancelledSeen = true;
                pg.cancelTransitions += 1;
            }
            if (pauseBaseline > pg.pauseBaseline) pg.pauseBaseline = pauseBaseline;

            address[] memory applicants = discovery.procurementApplicants(pid);
            address[] memory finalists = discovery.procurementFinalists(pid);

            for (uint256 i = 0; i < applicants.length; ++i) {
                address applicant = applicants[i];
                (bool revealed, bool shortlisted, bool finalistAccepted,, uint256 lockedStake,,,,,, bool everPromoted) =
                    discovery.applicationView(pid, applicant);
                if (lockedStake > 0) {
                    if (shortlisted || finalistAccepted || lockedStake > applicationStake) {
                        discoveryFinalists += lockedStake;
                    } else {
                        discoveryApplications += lockedStake;
                    }
                }
                bool settled = discovery.applicationSettled(pid, applicant);
                if (settled) applicationSettledSeen[pid][applicant] = true;
                if (everPromoted && !finalistEverPromotedSeen[pid][applicant]) {
                    finalistEverPromotedSeen[pid][applicant] = true;
                    pg.fallbackPromotions += 1;
                }
                revealed;
            }

            for (uint256 i = 0; i < finalists.length; ++i) {
                address finalist = finalists[i];
                for (uint256 v = 0; v < validators.length; ++v) {
                    address validator = validators[v];
                    (, bool revealedScore,, uint256 bond) = discovery.scoreCommitView(pid, finalist, validator);
                    if (bond > 0) discoveryScoreBonds += bond;
                    if (winnerFinalized || cancelled) {
                        if (revealedScore || bond == 0) scoreSettledSeen[pid][finalist][validator] = true;
                    }
                }
            }

            if (!winnerFinalized && !cancelled) {
                discoveryBudgets += uint256(finalistCount) * stipendPerFinalist + uint256(finalistCount)
                * uint256(maxReveals) * validatorRewardPerReveal;
                if (finalistStakeTotal < applicationStake) {
                    discoveryBudgets += 0;
                }
            }
        }

        expectedManagerLockedEscrow = managerEscrow;
        expectedManagerLockedAgentBonds = managerAgentBonds;
        expectedManagerLockedValidatorBonds = managerValidatorBonds;
        expectedManagerLockedDisputeBonds = managerDisputeBonds;

        expectedDiscoveryLockedApplicationStakes = discoveryApplications;
        expectedDiscoveryLockedFinalistStakes = discoveryFinalists;
        expectedDiscoveryLockedScoreBonds = discoveryScoreBonds;
        expectedDiscoveryBudgetReservations = discoveryBudgets;
        expectedDiscoveryClaimable = claimableTotal;
        completionNFTObservation = manager.completionNFT().nextTokenId();
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

    function invariant_managerGhostBucketsAndOneShotSettlement() external view {
        assertEq(manager.lockedEscrow(), handler.expectedManagerLockedEscrow(), "manager escrow ghost drift");
        assertEq(
            manager.lockedAgentBonds(), handler.expectedManagerLockedAgentBonds(), "manager agent bond ghost drift"
        );
        assertEq(
            manager.lockedValidatorBonds(),
            handler.expectedManagerLockedValidatorBonds(),
            "manager validator bond ghost drift"
        );
        assertEq(
            manager.lockedDisputeBonds(),
            handler.expectedManagerLockedDisputeBonds(),
            "manager dispute bond ghost drift"
        );

        uint256 locked = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), locked, "manager insolvent against ghost buckets");

        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (bool completed, bool completionRequested, bool disputed, bool expired,, bool validatorApproved) =
                manager.jobFlags(jobId);
            (,,,, uint256 validatorCount,, address assignedAgent,) = manager.jobAccounting(jobId);
            (uint256 approvals, uint256 disapprovals, uint256 validatorsLength) =
                manager.jobValidatorParticipation(jobId);
            (
                bool snapshotTaken,
                uint256 snapshotFingerprint,
                bool completedSeen,
                bool expiredSeen,
                bool disputedSeen,
                bool disputeResolvedSeen,
                uint256 completionTransitions,
                uint256 expiryTransitions,
                uint256 disputeOpenTransitions,
                uint256 disputeResolutionTransitions
            ) = handler.jobs(jobId);
            completedSeen;
            expiredSeen;
            disputedSeen;
            disputeResolvedSeen;
            assertFalse(completed && expired, "job cannot be completed and expired");
            assertFalse(completed && disputed, "job cannot be completed while disputed");
            assertEq(validatorsLength, approvals + disapprovals, "validator participation drift");
            assertEq(validatorCount, validatorsLength, "validator list length drift");
            if (validatorApproved) assertTrue(completionRequested, "approval requires completion request");
            if (assignedAgent != address(0) && !completed && !expired) {
                assertGt(manager.activeJobsByAgentView(assignedAgent), 0, "activeJobsByAgent drift");
            }
            if (snapshotTaken) assertEq(snapshotFingerprint, _fingerprint(jobId), "live job snapshot mutated");
            assertLe(completionTransitions, 1, "job completion settled more than once");
            assertLe(expiryTransitions, 1, "job expired more than once");
            assertLe(disputeOpenTransitions, 1, "dispute opened more than once");
            assertLe(disputeResolutionTransitions, 1, "dispute resolved more than once");
        }
    }

    function invariant_discoveryGhostAccountingAndTerminalCleanup() external view {
        uint256 expectedLocked = handler.expectedDiscoveryLockedApplicationStakes()
            + handler.expectedDiscoveryLockedFinalistStakes() + handler.expectedDiscoveryLockedScoreBonds()
            + handler.expectedDiscoveryBudgetReservations() + handler.expectedDiscoveryClaimable();
        assertGe(token.balanceOf(address(discovery)), expectedLocked, "discovery insolvent against ghost accounting");

        uint256 currentClaimable;
        address[] memory actors = handler.actorsView();
        for (uint256 i = 0; i < actors.length; ++i) {
            currentClaimable += discovery.claimable(actors[i]);
        }
        assertEq(currentClaimable, handler.expectedDiscoveryClaimable(), "claimable ghost drift");
        assertLe(currentClaimable, token.balanceOf(address(discovery)), "claimable exceeds discovery balance");

        for (uint256 pid = 0; pid < discovery.nextProcurementId(); ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            (
                address employer,
                uint256 jobId,
                bool shortlistFinalized,
                bool winnerFinalized,
                bool cancelled,
                uint64 pauseBaseline,
                uint64 commitDeadline,
                uint64 revealDeadline,
                uint64 finalistAcceptDeadline,
                uint64 trialDeadline,
                uint64 scoreCommitDeadline,
                uint64 scoreRevealDeadline,
                uint8 finalistCount,
                uint8 minValidatorReveals,
                uint8 maxValidatorReveals,
                uint256 applicationStake,
                uint256 finalistStakeTotal,
                uint256 stipendPerFinalist,
                uint256 validatorRewardPerReveal,,
                uint256 effectiveNow
            ) = discovery.procurementView(pid);
            (
                bool winnerSeen,
                bool cancelledSeen,
                uint256 winnerTransitions,
                uint256 cancelTransitions,
                uint256 fallbackPromotions,
                uint64 maxPauseBaseline
            ) = handler.procurements(pid);
            winnerSeen;
            cancelledSeen;
            assertTrue(employer != address(0), "procurement missing employer");
            assertEq(discovery.procurementByJobId(jobId), pid, "job linkage drift");
            assertTrue(discovery.hasProcurementByJobId(jobId), "job linkage flag missing");
            assertFalse(cancelled && winnerFinalized, "cancelled procurement finalized later");
            assertLe(applicationStake, finalistStakeTotal, "application stake exceeds finalist stake");
            assertGe(maxValidatorReveals, minValidatorReveals, "max reveals below min reveals");
            assertLe(winnerTransitions, 1, "winner finalized twice");
            assertLe(cancelTransitions, 1, "procurement cancelled twice");
            assertLe(fallbackPromotions, 1, "fallback promoted more than once");
            assertGe(maxPauseBaseline, pauseBaseline, "pause baseline regressed");

            if (shortlistFinalized && !winnerFinalized && !cancelled) {
                string memory action = discovery.nextActionForProcurement(pid);
                assertTrue(bytes(action).length > 0, "next action missing");
                if (keccak256(bytes(action)) == keccak256(bytes("FW"))) {
                    assertTrue(discovery.isWinnerFinalizable(pid), "helper said FW when not finalizable");
                }
            }

            if (effectiveNow <= commitDeadline) {
                assertFalse(discovery.isWinnerFinalizable(pid), "winner cannot finalize before commit phase ends");
            }
            if (effectiveNow <= revealDeadline) {
                assertFalse(shortlistFinalized, "shortlist finalized before reveal deadline");
            }
            if (effectiveNow <= finalistAcceptDeadline && winnerFinalized) {
                assertTrue(shortlistFinalized, "winner finalized without shortlist");
            }
            if (effectiveNow <= trialDeadline && winnerFinalized) {
                assertTrue(shortlistFinalized, "winner finalized before trials opened");
            }
            if (effectiveNow <= scoreCommitDeadline && winnerFinalized) {
                assertTrue(shortlistFinalized, "winner finalized before score commit deadline");
            }
            if (effectiveNow <= scoreRevealDeadline && winnerFinalized) {
                assertTrue(shortlistFinalized, "winner finalized before score reveal deadline");
            }

            uint256 stipendCap = uint256(finalistCount) * stipendPerFinalist;
            uint256 rewardCap = uint256(finalistCount) * uint256(maxValidatorReveals) * validatorRewardPerReveal;
            uint256 localClaimables;
            address[] memory applicants = discovery.procurementApplicants(pid);
            address[] memory finalists = discovery.procurementFinalists(pid);
            assertLe(finalists.length, finalistCount, "too many finalists");
            for (uint256 i = 0; i < applicants.length; ++i) {
                address applicant = applicants[i];
                (
                    bool revealed,
                    bool shortlisted,
                    bool finalistAccepted,
                    bool trialSubmitted,
                    uint256 lockedStake,,,,
                    uint256 trialScoreBps,
                    uint256 compositeScoreBps,
                    bool everPromoted
                ) = discovery.applicationView(pid, applicant);
                if (shortlisted) assertTrue(revealed, "shortlisted => revealed broken");
                if (finalistAccepted) assertTrue(shortlisted, "accepted => shortlisted broken");
                if (trialSubmitted) assertTrue(finalistAccepted, "trial => acceptance broken");
                if (compositeScoreBps > 0) {
                    assertTrue(shortlisted, "composite requires shortlist");
                    assertTrue(finalistAccepted, "composite requires acceptance");
                    assertTrue(trialSubmitted, "composite requires trial");
                }
                if (trialScoreBps > 0) assertTrue(trialSubmitted, "trial score requires trial submission");
                if (everPromoted) assertTrue(shortlisted, "promotion requires shortlist");
                if (winnerFinalized || cancelled) {
                    if (handler.applicationSettledSeen(pid, applicant)) {
                        assertEq(lockedStake, 0, "settled application still locked");
                    }
                }
                localClaimables += discovery.claimable(applicant);
            }
            for (uint256 i = 0; i < finalists.length; ++i) {
                address finalist = finalists[i];
                assertLe(discovery.revealedScoreCount(pid, finalist), maxValidatorReveals, "score reveals exceeded cap");
                for (uint256 v = 0; v < 4; ++v) {
                    address validator = address(uint160(0x3000 + v));
                    (, bool revealedScore,, uint256 bond) = discovery.scoreCommitView(pid, finalist, validator);
                    if ((winnerFinalized || cancelled) && !revealedScore) {
                        assertEq(bond, 0, "unrevealed validator bond stranded");
                    }
                    if (handler.scoreSettledSeen(pid, finalist, validator)) {
                        assertTrue(revealedScore || bond == 0, "score settlement marker drift");
                    }
                    localClaimables += discovery.claimable(validator);
                }
            }
            assertLe(localClaimables, token.balanceOf(address(discovery)), "local claimables exceed balance");
            assertLe(
                stipendCap + rewardCap,
                token.balanceOf(address(discovery)) + handler.observedClaimablePaidOut(),
                "budget overrun"
            );
        }
    }

    function invariant_completionNftAndClaimReplaySafety() external view {
        uint256 completedJobs;
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (bool completed,,,,,) = manager.jobFlags(jobId);
            if (completed) completedJobs += 1;
        }
        assertLe(handler.completionNFTObservation(), completedJobs, "completion NFT minted off non-completion path");
        assertLe(
            handler.observedClaimablePaidOut(),
            token.balanceOf(address(discovery)) + handler.observedClaimablePaidOut(),
            "claim accounting underflow"
        );
    }
}
