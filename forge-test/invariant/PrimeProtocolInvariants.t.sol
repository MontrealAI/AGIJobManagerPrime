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
import "contracts/periphery/AGIJobCompletionNFT.sol";

contract PrimeProtocolHandler is Test {
    AGIJobManagerPrimeHarness public manager;
    AGIJobDiscoveryPrimeHarness public discovery;
    MockERC20 public token;
    AGIJobCompletionNFT public completionNFT;

    address public managerOwner;
    address public discoveryOwner;
    address public moderator;
    address public pendingDiscoveryOwner;

    address[] public employers;
    address[] public agents;
    address[] public validators;
    address[] public actors;

    MockENSJobPages public healthyHook;
    MockENSJobPagesMalformed public hostileHook;

    uint256 internal constant MAX_MANAGER_JOBS = 32;
    uint256 internal constant MAX_DISCOVERY_PROCUREMENTS = 32;

    mapping(uint256 => bool) public snapshotTaken;
    mapping(uint256 => uint256) public snapshotFingerprint;
    mapping(uint256 => bool) public disputeOpened;
    mapping(uint256 => uint256) public disputeSettlementCount;
    mapping(uint256 => uint256) public validatorSettlementCount;
    mapping(uint256 => uint256) public agentBondSettlementCount;
    mapping(uint256 => uint256) public previousDisputeBond;
    mapping(uint256 => uint256) public previousValidatorBond;
    mapping(uint256 => uint256) public previousAgentBond;
    mapping(uint256 => bool) public previousDisputed;
    mapping(uint256 => bool) public previousCompleted;
    mapping(uint256 => bool) public previousExpired;

    mapping(uint256 => bool) public procurementObserved;
    mapping(uint256 => bool) public procurementWinnerFinalizedSeen;
    mapping(uint256 => bool) public procurementCancelledSeen;
    mapping(uint256 => mapping(address => bool)) public everPromotedSeen;
    mapping(uint256 => mapping(address => uint256)) public promotionCount;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public validatorScoreSettlementCount;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public previousScoreBond;

    constructor(AGIJobManagerPrimeHarness _manager, AGIJobDiscoveryPrimeHarness _discovery, MockERC20 _token) {
        manager = _manager;
        discovery = _discovery;
        token = _token;
        completionNFT = _manager.completionNFT();
        managerOwner = manager.owner();
        discoveryOwner = discovery.owner();
        moderator = address(0xBEEF);

        MockERC721 agiType = new MockERC721();
        healthyHook = new MockENSJobPages();
        hostileHook = new MockENSJobPagesMalformed();
        hostileHook.setTokenURIBytes(hex"00");

        vm.startPrank(managerOwner);
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
            vm.prank(managerOwner);
            manager.addAdditionalAgent(agent);
            vm.prank(managerOwner);
            manager.addAdditionalValidator(validator);
        }

        actors.push(managerOwner);
        actors.push(discoveryOwner);
        actors.push(moderator);
        token.mint(moderator, 100_000 ether);
        vm.prank(moderator);
        token.approve(address(manager), type(uint256).max);
    }

    function actorsView() external view returns (address[] memory) {
        return actors;
    }

    function validatorsView() external view returns (address[] memory) {
        return validators;
    }

    function _jobFingerprint(uint256 jobId) internal view returns (uint256) {
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

    function jobSnapshot(uint256 jobId) external view returns (uint256) {
        return _jobFingerprint(jobId);
    }

    function _syncJob(uint256 jobId) internal {
        if (!manager.jobExists(jobId)) return;
        (bool completed, bool completionRequested, bool disputed, bool expired,,) = manager.jobFlags(jobId);
        (, uint256 agentBondAmount, uint256 disputeBondAmount, uint256 validatorBondAmount,,, address assignedAgent,) =
            manager.jobAccounting(jobId);

        if (assignedAgent != address(0) && !snapshotTaken[jobId]) {
            snapshotTaken[jobId] = true;
            snapshotFingerprint[jobId] = _jobFingerprint(jobId);
        }

        if (disputed) disputeOpened[jobId] = true;
        if (previousDisputed[jobId] && !disputed) {
            disputeSettlementCount[jobId] += 1;
            assert(disputeSettlementCount[jobId] <= 1);
        }
        if (previousValidatorBond[jobId] > 0 && validatorBondAmount == 0) {
            validatorSettlementCount[jobId] += 1;
            assert(validatorSettlementCount[jobId] <= 1);
        }
        if (previousAgentBond[jobId] > 0 && agentBondAmount == 0) {
            agentBondSettlementCount[jobId] += 1;
            assert(agentBondSettlementCount[jobId] <= 1);
        }

        if (previousCompleted[jobId]) assert(completed);
        if (previousExpired[jobId]) assert(expired);
        if (completed) assert(completionRequested);
        if (expired) assert(!completed);

        previousDisputed[jobId] = disputed;
        previousCompleted[jobId] = completed;
        previousExpired[jobId] = expired;
        previousDisputeBond[jobId] = disputeBondAmount;
        previousValidatorBond[jobId] = validatorBondAmount;
        previousAgentBond[jobId] = agentBondAmount;

        if (!completionRequested) {
            assert(!disputed);
        }
    }

    function _syncProcurement(uint256 procurementId) internal {
        if (!discovery.procurementExists(procurementId)) return;
        procurementObserved[procurementId] = true;
        (,, bool shortlistFinalized, bool winnerFinalized, bool cancelled,,,,,,,,,,,,,,,,) =
            discovery.procurementView(procurementId);
        if (procurementWinnerFinalizedSeen[procurementId]) assert(winnerFinalized);
        if (procurementCancelledSeen[procurementId]) assert(cancelled);
        if (winnerFinalized) procurementWinnerFinalizedSeen[procurementId] = true;
        if (cancelled) procurementCancelledSeen[procurementId] = true;
        if (cancelled) assert(!winnerFinalized);

        address[] memory applicants = discovery.procurementApplicants(procurementId);
        address[] memory finalists = discovery.procurementFinalists(procurementId);

        for (uint256 i = 0; i < applicants.length; ++i) {
            (bool revealed, bool shortlisted, bool finalistAccepted, bool trialSubmitted,,,,,,, bool everPromoted) =
                discovery.applicationView(procurementId, applicants[i]);
            bool settled = discovery.applicationSettled(procurementId, applicants[i]);

            if (shortlisted) assert(revealed);
            if (finalistAccepted) assert(shortlisted);
            if (trialSubmitted) assert(finalistAccepted);
            if (everPromoted && !everPromotedSeen[procurementId][applicants[i]]) {
                everPromotedSeen[procurementId][applicants[i]] = true;
                promotionCount[procurementId][applicants[i]] += 1;
                assert(promotionCount[procurementId][applicants[i]] <= 1);
            }
            if (settled && cancelled) {
                // settled applications must remain settled after terminal cancellation/finalization
                assert(settled);
            }
        }

        for (uint256 i = 0; i < finalists.length; ++i) {
            address finalist = finalists[i];
            for (uint256 v = 0; v < validators.length; ++v) {
                (, bool revealedScore,, uint256 bond) =
                    discovery.scoreCommitView(procurementId, finalist, validators[v]);
                if (previousScoreBond[procurementId][finalist][validators[v]] > 0 && bond == 0) {
                    validatorScoreSettlementCount[procurementId][finalist][validators[v]] += 1;
                    assert(validatorScoreSettlementCount[procurementId][finalist][validators[v]] <= 1);
                }
                if (winnerFinalized || cancelled) {
                    if (!revealedScore) assert(bond == 0);
                }
                previousScoreBond[procurementId][finalist][validators[v]] = bond;
            }
        }

        if (winnerFinalized || cancelled || shortlistFinalized) {
            assert(procurementObserved[procurementId]);
        }
    }

    function _syncAll() internal {
        uint256 nextJobId = manager.nextJobId();
        for (uint256 jobId = 0; jobId < nextJobId; ++jobId) {
            _syncJob(jobId);
        }
        uint256 nextProcurementId = discovery.nextProcurementId();
        for (uint256 pid = 0; pid < nextProcurementId; ++pid) {
            _syncProcurement(pid);
        }
    }

    function _boundDelta(uint256 seed) internal view returns (uint256) {
        uint256 mode = bound(seed, 0, 8);
        if (mode == 0) return 1;
        if (mode == 1) return 2;
        if (mode == 2) return 1 days - 1;
        if (mode == 3) return 1 days;
        if (mode == 4) return 1 days + 1;
        if (mode == 5) return 7 days;
        if (mode == 6) return 14 days;
        if (mode == 7) return 30 days;
        return 90 days;
    }

    function warp(uint256 seed) external {
        vm.warp(block.timestamp + _boundDelta(seed));
        _syncAll();
    }

    function warpAroundJobBoundary(uint256 jobSeed, uint8 boundaryKind, uint8 offsetMode) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (!manager.jobExists(jobId)) return;
        (
            uint64 selectionExpiresAt,
            uint64 checkpointDeadline,
            uint64 assignedAt,
            uint64 completionRequestedAt,
            uint64 disputedAt,
            uint64 approvedAt,,
        ) = manager.jobTiming(jobId);
        (uint64 completionReview, uint64 disputeReview, uint64 challengePeriod,,,,,,) = manager.jobSnapshots(jobId);
        (,,,,,, address assignedAgent,) = manager.jobAccounting(jobId);
        uint256 anchor;
        uint8 kind = uint8(bound(boundaryKind, 0, 4));
        if (kind == 0 && assignedAgent != address(0)) {
            (, uint256 payout,,,,,,) = manager.jobAccounting(jobId);
            payout;
            (, uint64 checkpoint,,,,,,) = manager.jobTiming(jobId);
            checkpoint;
            (,, uint64 assignedAt2,,,,,) = manager.jobTiming(jobId);
            (,,, uint256 duration,,,,,) = manager.jobCore(jobId);
            anchor = uint256(assignedAt2) + duration;
        } else if (kind == 1 && completionRequestedAt != 0) {
            anchor = uint256(completionRequestedAt) + completionReview;
        } else if (kind == 2 && disputedAt != 0) {
            anchor = uint256(disputedAt) + disputeReview;
        } else if (kind == 3 && approvedAt != 0) {
            anchor = uint256(approvedAt) + challengePeriod;
        } else if (selectionExpiresAt != 0) {
            anchor = selectionExpiresAt;
        } else if (checkpointDeadline != 0) {
            anchor = checkpointDeadline;
        } else {
            return;
        }

        uint8 mode = uint8(bound(offsetMode, 0, 2));
        uint256 target = anchor;
        if (mode == 0 && anchor > 0) target = anchor - 1;
        else if (mode == 2) target = anchor + 1;
        if (target < block.timestamp) target = block.timestamp;
        vm.warp(target);
        _syncJob(jobId);
    }

    function warpAroundProcurementBoundary(uint256 procurementSeed, uint8 boundaryKind, uint8 offsetMode) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        if (!discovery.procurementExists(pid)) return;
        (
            ,,,,,,
            uint64 commitDeadline,
            uint64 revealDeadline,
            uint64 finalistAcceptDeadline,
            uint64 trialDeadline,
            uint64 scoreCommitDeadline,
            uint64 scoreRevealDeadline,,,,,,,,,
        ) = discovery.procurementView(pid);
        uint256 anchor;
        uint8 kind = uint8(bound(boundaryKind, 0, 5));
        if (kind == 0) anchor = commitDeadline;
        else if (kind == 1) anchor = revealDeadline;
        else if (kind == 2) anchor = finalistAcceptDeadline;
        else if (kind == 3) anchor = trialDeadline;
        else if (kind == 4) anchor = scoreCommitDeadline;
        else anchor = scoreRevealDeadline;

        uint8 mode = uint8(bound(offsetMode, 0, 2));
        uint256 target = anchor;
        if (mode == 0 && anchor > 0) target = anchor - 1;
        else if (mode == 2) target = anchor + 1;
        if (target < block.timestamp) target = block.timestamp;
        vm.warp(target);
        _syncProcurement(pid);
    }

    function togglePauses(uint256 seed) external {
        vm.startPrank(managerOwner);
        manager.setSettlementPaused((seed & 1) == 1);
        if ((seed & 2) == 2) manager.pause();
        else manager.unpause();
        manager.setEnsJobPages((seed & 16) == 16 ? address(hostileHook) : address(healthyHook));
        hostileHook.setRevertOnHook((seed & 32) == 32);
        vm.stopPrank();

        vm.prank(discovery.owner());
        discovery.setIntakePaused((seed & 4) == 4);
        vm.prank(discovery.owner());
        if ((seed & 8) == 8) discovery.pause();
        else if (discovery.paused()) discovery.unpause();

        _syncAll();
    }

    function ownerActions(uint256 seed, uint256 valueSeed) external {
        vm.startPrank(managerOwner);
        manager.setRequiredValidatorApprovals(bound(seed, 1, 2));
        manager.setRequiredValidatorDisapprovals(bound(seed >> 8, 1, 2));
        manager.setVoteQuorum(bound(seed >> 16, 1, 2));
        manager.setChallengePeriodAfterApproval(bound(valueSeed, 1 hours, 3 days));
        manager.setPremiumReputationThreshold(bound(valueSeed >> 32, 0, 1_000));
        vm.stopPrank();
        _syncAll();
    }

    function discoveryOwnershipFlow(uint8 mode, uint256 actorSeed) external {
        address currentOwner = discovery.owner();
        address candidate = actors[bound(actorSeed, 0, actors.length - 1)];
        if (candidate == address(0) || candidate == currentOwner) {
            candidate = employers[0];
        }

        if (mode % 3 == 0) {
            vm.prank(currentOwner);
            try discovery.transferOwnership(candidate) {
                pendingDiscoveryOwner = candidate;
            } catch {}
        } else if (mode % 3 == 1) {
            address pending = discovery.pendingOwner();
            if (pending != address(0)) {
                vm.prank(pending);
                try discovery.acceptOwnership() {
                    discoveryOwner = pending;
                    pendingDiscoveryOwner = address(0);
                } catch {}
            }
        } else {
            if (discovery.pendingOwner() != address(0)) {
                vm.prank(currentOwner);
                try discovery.cancelOwnershipTransfer() {
                    pendingDiscoveryOwner = address(0);
                } catch {}
            }
        }
        _syncAll();
    }

    function createManagerJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed, bool selectedOnly)
        external
    {
        if (manager.nextJobId() >= MAX_MANAGER_JOBS) return;
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
            _syncJob(jobId);
            if (selectedOnly) {
                vm.prank(managerOwner);
                try manager.designateSelectedAgent(
                    jobId, agents[jobId % agents.length], 2 days, uint64(jobId % 2 == 0 ? 1 days : 0)
                ) {}
                    catch {}
                _syncJob(jobId);
            }
        } catch {}
    }

    function createDiscoveryJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed, uint256 cfgSeed)
        external
    {
        if (discovery.nextProcurementId() >= MAX_DISCOVERY_PROCUREMENTS || manager.nextJobId() >= MAX_MANAGER_JOBS) {
            return;
        }
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
            selectedAcceptanceWindow: uint64(bound(cfgSeed, 30, 120)),
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
        if (proc.finalistStakeTotal < proc.applicationStake) proc.finalistStakeTotal = proc.applicationStake;
        if (proc.maxValidatorRevealsPerFinalist < proc.minValidatorReveals) {
            proc.maxValidatorRevealsPerFinalist = proc.minValidatorReveals;
        }
        vm.prank(employer);
        try discovery.createPremiumJobWithDiscovery(premium, proc) returns (uint256 jobId, uint256 procurementId) {
            _syncJob(jobId);
            _syncProcurement(procurementId);
        } catch {}
    }

    function applyManagerJob(uint256 jobSeed, uint256 agentSeed) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        address agent = agents[bound(agentSeed, 0, agents.length - 1)];
        vm.prank(agent);
        try manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0)) {} catch {}
        _syncJob(jobId);
    }

    function submitCheckpoint(uint256 jobSeed, uint256 agentSeed) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        vm.prank(agents[bound(agentSeed, 0, agents.length - 1)]);
        try manager.submitCheckpoint(jobId, "ipfs://checkpoint") {} catch {}
        _syncJob(jobId);
    }

    function failCheckpoint(uint256 jobSeed) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        try manager.failCheckpoint(jobId) {} catch {}
        _syncJob(jobId);
    }

    function requestCompletion(uint256 jobSeed, uint256 agentSeed) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        vm.prank(agents[bound(agentSeed, 0, agents.length - 1)]);
        try manager.requestJobCompletion(jobId, "ipfs://done") {} catch {}
        _syncJob(jobId);
    }

    function vote(uint256 jobSeed, uint256 validatorSeed, bool approveVote) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        vm.prank(validators[bound(validatorSeed, 0, validators.length - 1)]);
        if (approveVote) {
            try manager.validateJob(jobId, "", new bytes32[](0)) {} catch {}
        } else {
            try manager.disapproveJob(jobId, "", new bytes32[](0)) {} catch {}
        }
        _syncJob(jobId);
    }

    function dispute(uint256 jobSeed, bool employerSide) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        (,,,,, address employer, address assignedAgent,) = manager.jobAccounting(jobId);
        address actor = employerSide ? employer : assignedAgent;
        if (actor == address(0)) return;
        vm.prank(actor);
        try manager.disputeJob(jobId) {} catch {}
        _syncJob(jobId);
    }

    function resolveDispute(uint256 jobSeed, uint8 code, bool stale, bool employerWins) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (stale) {
            vm.prank(managerOwner);
            try manager.resolveStaleDispute(jobId, employerWins) {} catch {}
        } else {
            vm.prank(moderator);
            try manager.resolveDisputeWithCode(jobId, uint8(bound(code, 1, 2)), "mod") {} catch {}
        }
        _syncJob(jobId);
    }

    function finalizeOrExpire(uint256 jobSeed, bool finalizeJob_) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (finalizeJob_) {
            try manager.finalizeJob(jobId) {} catch {}
        } else {
            try manager.expireJob(jobId) {} catch {}
        }
        _syncJob(jobId);
    }

    function cancelJob(uint256 jobSeed) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        address employer = manager.jobEmployerOf(jobId);
        if (employer == address(0)) return;
        vm.prank(employer);
        try manager.cancelJob(jobId) {} catch {}
        _syncJob(jobId);
    }

    function commitApplication(uint256 procurementSeed, uint256 agentSeed, uint256 saltSeed) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address agent = agents[bound(agentSeed, 0, agents.length - 1)];
        bytes32 salt = bytes32(saltSeed);
        bytes32 commitment = keccak256(abi.encodePacked(pid, agent, "ipfs://app", salt));
        vm.prank(agent);
        try discovery.commitApplication(pid, commitment, "", new bytes32[](0)) {} catch {}
        _syncProcurement(pid);
    }

    function revealApplication(uint256 procurementSeed, uint256 agentSeed, uint256 saltSeed) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        vm.prank(agents[bound(agentSeed, 0, agents.length - 1)]);
        try discovery.revealApplication(pid, "", new bytes32[](0), bytes32(saltSeed), "ipfs://app") {} catch {}
        _syncProcurement(pid);
    }

    function advanceProcurement(uint256 procurementSeed, uint256 actorSeed) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(actor);
        try discovery.advanceProcurement(pid) {} catch {}
        _syncProcurement(pid);
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
        _syncProcurement(pid);
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
        _syncProcurement(pid);
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
        _syncProcurement(pid);
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

    function invariant_managerTokenConservationAndStateMachine() external view {
        uint256 managerLocked = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), managerLocked, "manager insolvent");

        uint256 nextJobId = manager.nextJobId();
        uint256 activeAssignedJobs;
        uint256 nftSupplyLike;
        for (uint256 jobId = 0; jobId < nextJobId; ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (
                bool completed,
                bool completionRequested,
                bool disputed,
                bool expired,
                bool escrowReleased,
                bool validatorApproved
            ) = manager.jobFlags(jobId);
            (
                uint256 payout,
                uint256 agentBondAmount,
                uint256 disputeBondAmount,
                uint256 validatorBondAmount,
                uint256 validatorCount,,
                address assignedAgent,
                address selectedAgent
            ) = manager.jobAccounting(jobId);
            (uint256 approvals, uint256 disapprovals, uint256 validatorsLength) =
                manager.jobValidatorParticipation(jobId);

            assertFalse(completed && expired, "job cannot be completed and expired");
            assertFalse(completed && disputed, "job cannot be completed while disputed");
            if (validatorApproved) assertTrue(completionRequested, "approval requires completion request");
            if (disputed) assertTrue(completionRequested, "dispute requires completion request");
            assertEq(validatorsLength, approvals + disapprovals, "vote count drift");
            assertEq(validatorCount, validatorsLength, "validator list drift");
            assertLe(handler.disputeSettlementCount(jobId), 1, "dispute settled twice");
            assertLe(handler.validatorSettlementCount(jobId), 1, "validator bond settled twice");
            assertLe(handler.agentBondSettlementCount(jobId), 1, "agent bond settled twice");
            if (handler.snapshotTaken(jobId)) {
                assertEq(handler.snapshotFingerprint(jobId), handler.jobSnapshot(jobId), "live snapshot mutated");
            }
            if (selectedAgent != address(0)) {
                assertTrue(assignedAgent == address(0) || assignedAgent == selectedAgent, "selected-agent drift");
            }
            if (assignedAgent != address(0) && !completed && !expired) {
                activeAssignedJobs += 1;
                assertGt(manager.activeJobsByAgentView(assignedAgent), 0, "activeJobsByAgent drift");
            }
            if (completed) {
                nftSupplyLike += 1;
                assertTrue(escrowReleased, "completed jobs must release escrow");
                assertEq(agentBondAmount, 0, "completed jobs cannot keep agent bond locked");
                assertEq(disputeBondAmount, 0, "completed jobs cannot keep dispute bond locked");
                assertEq(validatorBondAmount, 0, "completed jobs cannot keep validator bonds locked");
            }
            if (expired) {
                assertTrue(escrowReleased, "expired jobs must release escrow");
                assertEq(agentBondAmount, 0, "expired jobs cannot keep agent bond locked");
                assertEq(disputeBondAmount, 0, "expired jobs cannot keep dispute bond locked");
                assertEq(validatorBondAmount, 0, "expired jobs cannot keep validator bonds locked");
            }
            if (!escrowReleased) assertEq(payout > 0, true, "unreleased escrow must map to funded payout");
        }
        assertEq(handler.completionNFT().nextTokenId(), nftSupplyLike, "completion NFT only on true completions");
        manager.withdrawableAGI();
        activeAssignedJobs;
    }

    function invariant_managerLockedBucketsMatchPerJobAccounting() external view {
        uint256 nextJobId = manager.nextJobId();
        uint256 escrow;
        uint256 agentBonds;
        uint256 disputeBonds;
        uint256 validatorBonds;
        for (uint256 jobId = 0; jobId < nextJobId; ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (bool completed,, bool disputed, bool expired, bool escrowReleased,) = manager.jobFlags(jobId);
            (
                uint256 payout,
                uint256 agentBondAmount,
                uint256 disputeBondAmount,
                uint256 validatorBondAmount,
                uint256 validatorCount,,,
            ) = manager.jobAccounting(jobId);
            if (!escrowReleased) escrow += payout;
            if (!completed && !expired) {
                agentBonds += agentBondAmount;
                disputeBonds += disputeBondAmount;
                if (disputed || validatorCount > 0) {
                    validatorBonds += validatorBondAmount * validatorCount;
                }
            }
        }
        assertEq(manager.lockedEscrow(), escrow, "escrow accounting drift");
        assertEq(manager.lockedAgentBonds(), agentBonds, "agent bond drift");
        assertEq(manager.lockedDisputeBonds(), disputeBonds, "dispute bond drift");
        assertEq(manager.lockedValidatorBonds(), validatorBonds, "validator bond drift");
    }

    function invariant_discoveryTokenConservationAndClaimableCoverage() external view {
        uint256 nextProcurementId = discovery.nextProcurementId();
        uint256 lockedDiscovery;
        uint256 stipendPaid;
        uint256 rewardPaid;
        for (uint256 pid = 0; pid < nextProcurementId; ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            (
                address employer,
                uint256 jobId,
                bool shortlistFinalized,
                bool winnerFinalized,
                bool cancelled,,,,,,,,
                uint8 finalistCount,
                uint8 minValidatorReveals,
                uint8 maxValidatorReveals,
                uint256 applicationStake,
                uint256 finalistStakeTotal,
                uint256 stipendPerFinalist,
                uint256 validatorRewardPerReveal,
                uint256 validatorScoreBond,
            ) = discovery.procurementView(pid);
            assertTrue(employer != address(0), "missing employer");
            assertEq(discovery.procurementByJobId(jobId), pid, "job linkage drift");
            assertTrue(discovery.hasProcurementByJobId(jobId), "job linkage flag missing");
            assertFalse(cancelled && winnerFinalized, "cancelled procurement cannot finalize winner");
            assertGe(finalistStakeTotal, applicationStake, "stake inversion");

            address[] memory applicants = discovery.procurementApplicants(pid);
            address[] memory finalists = discovery.procurementFinalists(pid);
            assertLe(finalists.length, finalistCount, "too many finalists");

            uint256 acceptedFinalists;
            uint256 trialFinalists;
            for (uint256 i = 0; i < applicants.length; ++i) {
                (
                    bool revealed,
                    bool shortlisted,
                    bool finalistAccepted,
                    bool trialSubmitted,
                    uint256 lockedStake,,,
                    uint256 historicalScoreBps,
                    uint256 trialScoreBps,
                    uint256 compositeScoreBps,
                    bool everPromoted
                ) = discovery.applicationView(pid, applicants[i]);
                bool settled = discovery.applicationSettled(pid, applicants[i]);
                if (shortlisted) assertTrue(revealed, "shortlisted => revealed");
                if (finalistAccepted) {
                    acceptedFinalists += 1;
                    assertTrue(shortlisted, "accepted finalist must be shortlisted");
                }
                if (trialSubmitted) {
                    trialFinalists += 1;
                    assertTrue(finalistAccepted, "trial requires accepted finalist");
                }
                if (compositeScoreBps > 0) {
                    assertTrue(
                        shortlisted && finalistAccepted && trialSubmitted, "composite score requires full finalist path"
                    );
                    assertGt(historicalScoreBps + trialScoreBps, 0, "composite without score inputs");
                }
                if (everPromoted) assertLe(handler.promotionCount(pid, applicants[i]), 1, "double promotion observed");
                if ((winnerFinalized || cancelled) && settled) {
                    assertEq(lockedStake, 0, "terminal applications cannot strand stake");
                }
                lockedDiscovery += lockedStake;
            }

            for (uint256 i = 0; i < finalists.length; ++i) {
                uint256 reveals = discovery.revealedScoreCount(pid, finalists[i]);
                assertLe(reveals, maxValidatorReveals, "too many reveals per finalist");
                if (reveals > 0) rewardPaid += reveals * validatorRewardPerReveal;
                if (reveals >= minValidatorReveals) stipendPaid += stipendPerFinalist;

                address[] memory validators = handler.validatorsView();
                for (uint256 v = 0; v < validators.length; ++v) {
                    (, bool revealedScore,, uint256 bond) = discovery.scoreCommitView(pid, finalists[i], validators[v]);
                    assertLe(
                        handler.validatorScoreSettlementCount(pid, finalists[i], validators[v]),
                        1,
                        "validator score settled twice"
                    );
                    if (!revealedScore) {
                        assertLe(bond, validatorScoreBond, "validator bond exceeds configured bond");
                    }
                    lockedDiscovery += bond;
                }
            }

            uint256 totalBudget = uint256(finalistCount) * stipendPerFinalist + uint256(finalistCount)
                * uint256(maxValidatorReveals) * validatorRewardPerReveal;
            if (!winnerFinalized && !cancelled) {
                lockedDiscovery += totalBudget;
            }
            assertLe(
                stipendPaid, uint256(finalistCount) * stipendPerFinalist + stipendPaid, "stipend accounting overflow"
            );
            assertLe(rewardPaid, uint256(nextProcurementId + 1) * type(uint128).max, "reward accounting overflow");
            if (shortlistFinalized && !winnerFinalized && !cancelled) {
                string memory action = discovery.nextActionForProcurement(pid);
                if (keccak256(bytes(action)) == keccak256(bytes("FW"))) {
                    assertTrue(discovery.isWinnerFinalizable(pid), "FW helper lied");
                }
            }
            acceptedFinalists;
            trialFinalists;
        }

        uint256 claimableTotal;
        address[] memory actors = handler.actorsView();
        for (uint256 i = 0; i < actors.length; ++i) {
            claimableTotal += discovery.claimable(actors[i]);
        }
        assertGe(token.balanceOf(address(discovery)), lockedDiscovery + claimableTotal, "discovery insolvent");
        assertLe(claimableTotal, token.balanceOf(address(discovery)), "claimable drift above payability");
    }

    function invariant_pauseClocksHelperViewsAndOwnershipSafety() external view {
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

        uint256 nextJobId = manager.nextJobId();
        for (uint256 jobId = 0; jobId < nextJobId; ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (
                uint64 selectionExpiresAt,
                uint64 checkpointDeadline,
                uint64 assignedAt,
                uint64 completionRequestedAt,
                uint64 disputedAt,
                uint64 approvedAt,
                uint64 pauseBaseline,
                uint256 effectiveNow
            ) = manager.jobTiming(jobId);
            selectionExpiresAt;
            checkpointDeadline;
            assignedAt;
            completionRequestedAt;
            disputedAt;
            approvedAt;
            assertLe(uint256(pauseBaseline), block.timestamp, "job pause baseline in future");
            assertLe(effectiveNow, block.timestamp, "job effective timestamp advanced while paused");
        }

        assertEq(discovery.pendingOwner(), handler.pendingDiscoveryOwner(), "discovery pending owner drift");
        assertEq(address(handler.completionNFT()).code.length > 0, true, "completion NFT missing");
    }
}
