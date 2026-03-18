// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "forge-test/harness/AGIJobManagerPrimeHarness.sol";
import "forge-test/harness/AGIJobDiscoveryPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";
import "contracts/test/MockENSJobPages.sol";
import "contracts/test/MockENSJobPagesMalformed.sol";
import "contracts/test/HookGasBurner.sol";
import "contracts/periphery/AGIJobCompletionNFT.sol";

contract PrimeProtocolHandler is Test {
    struct GhostManagerJob {
        bool disputeSettled;
        bool validatorSettled;
        bool nftObserved;
        uint256 frozenCompletionReview;
        uint256 frozenDisputeReview;
        uint256 frozenChallengePeriod;
        uint256 frozenVoteQuorum;
        uint256 frozenApprovals;
        uint256 frozenDisapprovals;
        uint256 frozenSlashBps;
        uint256 frozenCompletionRequestedAt;
        uint256 frozenDisputedAt;
        uint256 frozenValidatorApprovedAt;
    }

    MockERC20 public immutable token;
    AGIJobManagerPrimeHarness public immutable manager;
    AGIJobDiscoveryPrimeHarness public immutable discovery;
    MockERC721 public immutable agiType;
    MockENSJobPages public immutable ensHookOk;
    MockENSJobPagesMalformed public immutable ensHookMalformed;
    HookGasBurner public immutable ensHookGasBurner;

    address public owner;
    address public moderator;
    address[] public employers;
    address[] public agents;
    address[] public validators;
    address[] public anyone;
    address[] public trackedActors;

    mapping(uint256 => GhostManagerJob) public ghostJobs;

    uint256 public lastObservedManagerBalance;
    uint256 public lastObservedDiscoveryBalance;
    uint256 public totalClaimableLowerBound;
    uint256 public totalDiscoveryLockedLowerBound;

    bytes32 internal constant EMPTY_ROOT = bytes32(0);

    constructor(
        MockERC20 _token,
        AGIJobManagerPrimeHarness _manager,
        AGIJobDiscoveryPrimeHarness _discovery,
        MockERC721 _agiType,
        MockENSJobPages _ensHookOk,
        MockENSJobPagesMalformed _ensHookMalformed,
        HookGasBurner _ensHookGasBurner
    ) {
        token = _token;
        manager = _manager;
        discovery = _discovery;
        agiType = _agiType;
        ensHookOk = _ensHookOk;
        ensHookMalformed = _ensHookMalformed;
        ensHookGasBurner = _ensHookGasBurner;

        owner = manager.owner();
        moderator = address(0xBEEFCAFE);

        employers.push(address(0x1001));
        employers.push(address(0x1002));
        employers.push(address(0x1003));

        agents.push(address(0x2001));
        agents.push(address(0x2002));
        agents.push(address(0x2003));
        agents.push(address(0x2004));

        validators.push(address(0x3001));
        validators.push(address(0x3002));
        validators.push(address(0x3003));
        validators.push(address(0x3004));

        anyone.push(address(0x4001));
        anyone.push(address(0x4002));
        anyone.push(address(0x4003));

        trackedActors.push(owner);
        trackedActors.push(moderator);

        vm.startPrank(owner);
        manager.addModerator(moderator);
        manager.setDiscoveryModule(address(discovery));
        manager.setRequiredValidatorApprovals(1);
        manager.setRequiredValidatorDisapprovals(1);
        manager.setVoteQuorum(1);
        manager.setChallengePeriodAfterApproval(2 days);
        manager.setCompletionReviewPeriod(3 days);
        manager.setDisputeReviewPeriod(5 days);
        manager.setPremiumReputationThreshold(0);
        manager.addOrUpdateAGIType(address(agiType), 90);
        manager.setEnsJobPages(address(_ensHookOk));
        for (uint256 i = 0; i < agents.length; ++i) {
            manager.addAdditionalAgent(agents[i]);
            agiType.mint(agents[i]);
            trackedActors.push(agents[i]);
        }
        for (uint256 i = 0; i < validators.length; ++i) {
            manager.addAdditionalValidator(validators[i]);
            trackedActors.push(validators[i]);
        }
        for (uint256 i = 0; i < employers.length; ++i) {
            trackedActors.push(employers[i]);
        }
        for (uint256 i = 0; i < anyone.length; ++i) {
            trackedActors.push(anyone[i]);
        }
        vm.stopPrank();

        for (uint256 i = 0; i < trackedActors.length; ++i) {
            token.mint(trackedActors[i], 2_000_000 ether);
            vm.prank(trackedActors[i]);
            token.approve(address(manager), type(uint256).max);
            vm.prank(trackedActors[i]);
            token.approve(address(discovery), type(uint256).max);
        }

        _refreshLowerBounds();
    }

    function _refreshLowerBounds() internal {
        lastObservedManagerBalance = token.balanceOf(address(manager));
        lastObservedDiscoveryBalance = token.balanceOf(address(discovery));

        uint256 claimableSum;
        for (uint256 i = 0; i < trackedActors.length; ++i) {
            claimableSum += discovery.claimable(trackedActors[i]);
        }
        totalClaimableLowerBound = claimableSum;
        totalDiscoveryLockedLowerBound = _discoveryLockedFromState();
    }

    function _discoveryLockedFromState() internal view returns (uint256 totalLocked) {
        for (uint256 procurementId = 0; procurementId < discovery.nextProcurementId(); ++procurementId) {
            (
                address employer,,,,,,,,,,,,,
                uint8 maxValidatorRevealsPerFinalist,
                uint256 applicationStake,
                uint256 finalistStakeTotal,
                uint256 stipendPerFinalist,
                uint256 validatorRewardPerReveal,
                uint256 validatorScoreBond,,,,
                uint256 applicantsLength,
                uint256 finalistsLength
            ) = discovery.procurementView(procurementId);
            if (employer == address(0)) continue;

            address[] memory applicants = discovery.procurementApplicants(procurementId);
            for (uint256 i = 0; i < applicants.length; ++i) {
                (,,,, uint256 lockedStake,,,,,,) = discovery.applicationView(procurementId, applicants[i]);
                totalLocked += lockedStake;
            }

            address[] memory finalists = discovery.procurementFinalists(procurementId);
            for (uint256 i = 0; i < finalists.length; ++i) {
                address[] memory scoreVals = discovery.scoreValidatorsList(procurementId, finalists[i]);
                for (uint256 j = 0; j < scoreVals.length; ++j) {
                    (,,, uint256 bond) = discovery.scoreCommitView(procurementId, finalists[i], scoreVals[j]);
                    totalLocked += bond;
                }
            }

            uint256 grossBudget = uint256(
                    finalistsLength == 0 ? maxValidatorRevealsPerFinalist : maxValidatorRevealsPerFinalist
                ) * validatorRewardPerReveal * finalistsLength + stipendPerFinalist * finalistsLength;
            // Lower bound intentionally omits unsettled remaining budget because it is not directly exposed.
            grossBudget;
            applicationStake;
            finalistStakeTotal;
            applicantsLength;
            validatorScoreBond;
        }
    }

    function _pick(address[] storage actors, uint256 seed) internal view returns (address) {
        return actors[bound(seed, 0, actors.length - 1)];
    }

    function _jobId(uint256 seed) internal view returns (uint256) {
        if (manager.nextJobId() == 0) return type(uint256).max;
        return bound(seed, 0, manager.nextJobId() - 1);
    }

    function _procurementId(uint256 seed) internal view returns (uint256) {
        if (discovery.nextProcurementId() == 0) return type(uint256).max;
        return bound(seed, 0, discovery.nextProcurementId() - 1);
    }

    function _scoreCommitment(uint256 procurementId, address finalist, address validator, uint8 score, bytes32 salt)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(procurementId, finalist, validator, score, salt));
    }

    function _appCommitment(uint256 procurementId, address agent, string memory uri, bytes32 salt)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(procurementId, agent, uri, salt));
    }

    function _warpAround(uint256 seed, uint256 base, uint256 maxExtra) internal {
        uint256 mode = seed % 6;
        if (mode == 0 && base > 0) vm.warp(base - 1);
        else if (mode == 1) vm.warp(base);
        else if (mode == 2) vm.warp(base + 1);
        else if (mode == 3) vm.warp(block.timestamp + bound(seed, 0, maxExtra));
        else if (mode == 4) vm.warp(base + bound(seed, 0, maxExtra));
        else vm.warp(block.timestamp + 1 + bound(seed, 0, maxExtra));
    }

    function createJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed) external {
        address employer = _pick(employers, employerSeed);
        uint256 payout = bound(payoutSeed, 1 ether, 500 ether);
        uint256 duration = bound(durationSeed, 1 hours, 14 days);
        vm.prank(employer);
        try manager.createJob("ipfs://prime/spec", payout, duration, "fuzz-job") returns (uint256 jobId) {
            GhostManagerJob storage g = ghostJobs[jobId];
            g.frozenVoteQuorum = manager.voteQuorum();
            g.frozenApprovals = manager.requiredValidatorApprovals();
            g.frozenDisapprovals = manager.requiredValidatorDisapprovals();
            g.frozenSlashBps = manager.validatorSlashBps();
        } catch {}
        _refreshLowerBounds();
    }

    function createPremiumProcurement(uint256 employerSeed, uint256 payoutSeed, uint256 timingSeed) external {
        address employer = _pick(employers, employerSeed);
        uint64 start = uint64(block.timestamp + 10 + bound(timingSeed, 0, 5));
        AGIJobDiscoveryPrime.ProcurementParams memory proc = AGIJobDiscoveryPrime.ProcurementParams({
            commitDeadline: start + 10,
            revealDeadline: start + 20,
            finalistAcceptDeadline: start + 30,
            trialDeadline: start + 40,
            scoreCommitDeadline: start + 50,
            scoreRevealDeadline: start + 60,
            selectedAcceptanceWindow: 20,
            checkpointWindow: 10,
            finalistCount: 2,
            minValidatorReveals: 1,
            maxValidatorRevealsPerFinalist: 3,
            historicalWeightBps: 3_000,
            trialWeightBps: 7_000,
            minReputation: 0,
            applicationStake: 1 ether,
            finalistStakeTotal: 2 ether,
            stipendPerFinalist: 1 ether,
            validatorRewardPerReveal: 0.25 ether,
            validatorScoreBond: 0.5 ether
        });
        AGIJobDiscoveryPrime.PremiumJobParams memory job = AGIJobDiscoveryPrime.PremiumJobParams({
            jobSpecURI: "ipfs://prime/premium-spec",
            payout: bound(payoutSeed, 10 ether, 200 ether),
            duration: 5 days,
            details: "premium"
        });
        vm.prank(employer);
        try discovery.createPremiumJobWithDiscovery(job, proc) returns (uint256 jobId, uint256) {
            GhostManagerJob storage g = ghostJobs[jobId];
            g.frozenVoteQuorum = manager.voteQuorum();
            g.frozenApprovals = manager.requiredValidatorApprovals();
            g.frozenDisapprovals = manager.requiredValidatorDisapprovals();
            g.frozenSlashBps = manager.validatorSlashBps();
        } catch {}
        _refreshLowerBounds();
    }

    function applyForJob(uint256 jobSeed, uint256 agentSeed) external {
        uint256 jobId = _jobId(jobSeed);
        if (jobId == type(uint256).max) return;
        vm.prank(_pick(agents, agentSeed));
        try manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0)) {} catch {}
        _refreshLowerBounds();
    }

    function requestCompletion(uint256 jobSeed, uint256 agentSeed) external {
        uint256 jobId = _jobId(jobSeed);
        if (jobId == type(uint256).max) return;
        vm.prank(_pick(agents, agentSeed));
        try manager.requestJobCompletion(jobId, "ipfs://prime/completion") {
            GhostManagerJob storage g = ghostJobs[jobId];
            (uint64 completionRequestedAt,,) = manager.jobTimestamps(jobId);
            (
                uint64 completionReviewPeriodSnapshot,
                uint64 disputeReviewPeriodSnapshot,
                uint64 challengePeriodAfterApprovalSnapshot,,,,
            ) = manager.jobSnapshots(jobId);
            g.frozenCompletionRequestedAt = completionRequestedAt;
            g.frozenCompletionReview = completionReviewPeriodSnapshot;
            g.frozenDisputeReview = disputeReviewPeriodSnapshot;
            g.frozenChallengePeriod = challengePeriodAfterApprovalSnapshot;
        } catch {}
        _refreshLowerBounds();
    }

    function validateOrDisapprove(uint256 jobSeed, uint256 validatorSeed, bool approveVote) external {
        uint256 jobId = _jobId(jobSeed);
        if (jobId == type(uint256).max) return;
        address validator = _pick(validators, validatorSeed);
        vm.prank(validator);
        if (approveVote) {
            try manager.validateJob(jobId, "", new bytes32[](0)) {
                ghostJobs[jobId].validatorSettled = false;
            } catch {}
        } else {
            try manager.disapproveJob(jobId, "", new bytes32[](0)) {
                ghostJobs[jobId].validatorSettled = false;
            } catch {}
        }
        _refreshLowerBounds();
    }

    function dispute(uint256 jobSeed, bool employerSide) external {
        uint256 jobId = _jobId(jobSeed);
        if (jobId == type(uint256).max) return;
        (address employer, address assignedAgent,) = manager.jobActors(jobId);
        address actor = employerSide ? employer : assignedAgent;
        if (actor == address(0)) return;
        vm.prank(actor);
        try manager.disputeJob(jobId) {
            ghostJobs[jobId].disputeSettled = false;
            (, uint64 disputedAt,) = manager.jobTimestamps(jobId);
            ghostJobs[jobId].frozenDisputedAt = disputedAt;
        } catch {}
        _refreshLowerBounds();
    }

    function resolveDispute(uint256 jobSeed, uint8 codeSeed, bool stale) external {
        uint256 jobId = _jobId(jobSeed);
        if (jobId == type(uint256).max) return;
        if (stale) {
            vm.warp(block.timestamp + bound(codeSeed, 1, 20 days));
            vm.prank(owner);
            try manager.resolveStaleDispute(jobId, codeSeed % 2 == 0) {
                ghostJobs[jobId].disputeSettled = true;
                ghostJobs[jobId].validatorSettled = true;
            } catch {}
        } else {
            vm.prank(moderator);
            try manager.resolveDisputeWithCode(jobId, uint8(bound(codeSeed, 1, 4)), "fuzz") {
                ghostJobs[jobId].disputeSettled = true;
                ghostJobs[jobId].validatorSettled = true;
            } catch {}
        }
        _refreshLowerBounds();
    }

    function finalizeOrExpire(uint256 jobSeed, uint256 warpSeed, bool finalizePath) external {
        uint256 jobId = _jobId(jobSeed);
        if (jobId == type(uint256).max) return;
        (,,,, uint256 duration,,,,,,,,,,,,,,,,,,,,,,,,) = manager.jobView(jobId);
        (,, uint64 validatorApprovedAt) = manager.jobTimestamps(jobId);
        (,, uint64 challengePeriodAfterApprovalSnapshot,,,,) = manager.jobSnapshots(jobId);
        if (finalizePath && validatorApprovedAt != 0) {
            _warpAround(warpSeed, uint256(validatorApprovedAt) + challengePeriodAfterApprovalSnapshot, 3 days);
            try manager.finalizeJob(jobId) {
                ghostJobs[jobId].validatorSettled = true;
                ghostJobs[jobId].disputeSettled = true;
                ghostJobs[jobId].nftObserved = true;
            } catch {}
        } else {
            _warpAround(warpSeed, block.timestamp + duration, 7 days);
            try manager.expireJob(jobId) {
                ghostJobs[jobId].validatorSettled = true;
                ghostJobs[jobId].disputeSettled = true;
            } catch {}
        }
        _refreshLowerBounds();
    }

    function cancelJob(uint256 jobSeed, uint256 employerSeed) external {
        uint256 jobId = _jobId(jobSeed);
        if (jobId == type(uint256).max) return;
        vm.prank(_pick(employers, employerSeed));
        try manager.cancelJob(jobId) {} catch {}
        _refreshLowerBounds();
    }

    function adminToggles(uint256 seed) external {
        vm.startPrank(owner);
        if (seed % 2 == 0) {
            try manager.pause() {} catch {}
        } else {
            try manager.unpause() {} catch {}
        }
        try manager.setSettlementPaused(seed % 3 == 0) {} catch {}
        try discovery.setIntakePaused(seed % 5 == 0) {} catch {}
        if (seed % 7 == 0) {
            try discovery.pause() {} catch {}
        } else if (seed % 7 == 1) {
            try discovery.unpause() {} catch {}
        }
        try manager.setCompletionReviewPeriod(bound(seed, 1 days, 9 days)) {} catch {}
        try manager.setDisputeReviewPeriod(bound(seed + 1, 2 days, 12 days)) {} catch {}
        try manager.setChallengePeriodAfterApproval(bound(seed + 2, 1 days, 8 days)) {} catch {}
        try manager.setVoteQuorum(bound(seed + 3, 1, 3)) {} catch {}
        try manager.setRequiredValidatorApprovals(bound(seed + 4, 1, 2)) {} catch {}
        try manager.setRequiredValidatorDisapprovals(bound(seed + 5, 1, 2)) {} catch {}
        vm.stopPrank();
        _refreshLowerBounds();
    }

    function setEnsHookMode(uint256 seed) external {
        vm.prank(owner);
        if (seed % 4 == 0) {
            manager.setEnsJobPages(address(ensHookOk));
        } else if (seed % 4 == 1) {
            manager.setEnsJobPages(address(ensHookMalformed));
        } else if (seed % 4 == 2) {
            manager.setEnsJobPages(address(ensHookGasBurner));
        } else {
            manager.setEnsJobPages(address(0));
        }
        ensHookMalformed.setRevertOnHook(seed % 3 == 0);
        ensHookOk.setRevertHook(uint8(bound(seed, 1, 5)), seed % 2 == 0);
        _refreshLowerBounds();
    }

    function commitApplication(uint256 procurementSeed, uint256 agentSeed, bytes32 salt) external {
        uint256 procurementId = _procurementId(procurementSeed);
        if (procurementId == type(uint256).max) return;
        address agent = _pick(agents, agentSeed);
        string memory uri = string.concat("ipfs://application/", vm.toString(uint256(uint160(agent))));
        bytes32 commitment = _appCommitment(procurementId, agent, uri, salt);
        vm.prank(agent);
        try discovery.commitApplication(procurementId, commitment, "", new bytes32[](0)) {} catch {}
        _refreshLowerBounds();
    }

    function revealApplication(uint256 procurementSeed, uint256 agentSeed, bytes32 salt, uint256 warpSeed) external {
        uint256 procurementId = _procurementId(procurementSeed);
        if (procurementId == type(uint256).max) return;
        (address employer,) = discovery.procurementActors(procurementId);
        if (employer == address(0)) return;
        (, uint64 revealDeadline,,,,) = discovery.procurementDeadlines(procurementId);
        _warpAround(warpSeed, revealDeadline, 3 days);
        address agent = _pick(agents, agentSeed);
        string memory uri = string.concat("ipfs://application/", vm.toString(uint256(uint160(agent))));
        vm.prank(agent);
        try discovery.revealApplication(procurementId, "", new bytes32[](0), salt, uri) {} catch {}
        _refreshLowerBounds();
    }

    function finalizeShortlist(uint256 procurementSeed, uint256 warpSeed) external {
        uint256 procurementId = _procurementId(procurementSeed);
        if (procurementId == type(uint256).max) return;
        (address employer,) = discovery.procurementActors(procurementId);
        if (employer == address(0)) return;
        (, uint64 revealDeadline,,,,) = discovery.procurementDeadlines(procurementId);
        _warpAround(warpSeed, revealDeadline, 5 days);
        try discovery.finalizeShortlist(procurementId) {} catch {}
        _refreshLowerBounds();
    }

    function acceptOrTrial(uint256 procurementSeed, uint256 agentSeed, uint256 warpSeed, bool submitTrialNow) external {
        uint256 procurementId = _procurementId(procurementSeed);
        if (procurementId == type(uint256).max) return;
        (address employer,,,,, uint64 finalistAcceptDeadline, uint64 trialDeadline,,,,,,,,,,,,,,,,,) =
            discovery.procurementView(procurementId);
        if (employer == address(0)) return;
        address agent = _pick(agents, agentSeed);
        if (submitTrialNow) {
            _warpAround(warpSeed, trialDeadline, 2 days);
            vm.prank(agent);
            try discovery.submitTrial(procurementId, "ipfs://trial") {} catch {}
        } else {
            _warpAround(warpSeed, finalistAcceptDeadline, 2 days);
            vm.prank(agent);
            try discovery.acceptFinalist(procurementId) {} catch {}
        }
        _refreshLowerBounds();
    }

    function commitOrRevealScore(
        uint256 procurementSeed,
        uint256 finalistSeed,
        uint256 validatorSeed,
        uint8 score,
        bytes32 salt,
        uint256 warpSeed,
        bool revealPhase
    ) external {
        uint256 procurementId = _procurementId(procurementSeed);
        if (procurementId == type(uint256).max) return;
        address[] memory finalists = discovery.procurementFinalists(procurementId);
        if (finalists.length == 0) return;
        address finalist = finalists[bound(finalistSeed, 0, finalists.length - 1)];
        address validator = _pick(validators, validatorSeed);
        if (revealPhase) {
            (,,,, uint64 scoreCommitDeadline, uint64 scoreRevealDeadline) =
                discovery.procurementDeadlines(procurementId);
            scoreCommitDeadline;
            _warpAround(warpSeed, scoreRevealDeadline, 3 days);
            vm.prank(validator);
            try discovery.revealFinalistScore(
                procurementId, finalist, uint8(bound(score, 0, 100)), salt, "", new bytes32[](0)
            ) {}
                catch {}
        } else {
            (,,,, uint64 scoreCommitDeadline,) = discovery.procurementDeadlines(procurementId);
            _warpAround(warpSeed, scoreCommitDeadline, 2 days);
            vm.prank(validator);
            try discovery.commitFinalistScore(
                procurementId,
                finalist,
                _scoreCommitment(procurementId, finalist, validator, uint8(bound(score, 0, 100)), salt),
                "",
                new bytes32[](0)
            ) {}
                catch {}
        }
        _refreshLowerBounds();
    }

    function finalizeWinnerOrFallback(uint256 procurementSeed, uint256 warpSeed, bool fallbackMode) external {
        uint256 procurementId = _procurementId(procurementSeed);
        if (procurementId == type(uint256).max) return;
        if (fallbackMode) {
            vm.warp(block.timestamp + bound(warpSeed, 0, 5 days));
            try discovery.promoteFallbackFinalist(procurementId) {} catch {}
        } else {
            (,,,,, uint64 scoreRevealDeadline) = discovery.procurementDeadlines(procurementId);
            _warpAround(warpSeed, scoreRevealDeadline, 4 days);
            try discovery.finalizeWinner(procurementId) {} catch {}
        }
        _refreshLowerBounds();
    }

    function cancelProcurement(uint256 procurementSeed, bool byOwner) external {
        uint256 procurementId = _procurementId(procurementSeed);
        if (procurementId == type(uint256).max) return;
        (address employer,) = discovery.procurementActors(procurementId);
        if (employer == address(0)) return;
        vm.prank(byOwner ? owner : employer);
        try discovery.cancelProcurement(procurementId) {} catch {}
        _refreshLowerBounds();
    }

    function claimDiscovery(uint256 actorSeed) external {
        address actor = trackedActors[bound(actorSeed, 0, trackedActors.length - 1)];
        vm.prank(actor);
        try discovery.claim() {} catch {}
        _refreshLowerBounds();
    }

    function trackedActorsLength() external view returns (uint256) {
        return trackedActors.length;
    }

    function ghostJobSnapshot(uint256 jobId)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        GhostManagerJob storage g = ghostJobs[jobId];
        return (
            g.frozenVoteQuorum,
            g.frozenApprovals,
            g.frozenDisapprovals,
            g.frozenSlashBps,
            g.frozenCompletionRequestedAt,
            g.frozenCompletionReview,
            g.frozenDisputeReview,
            g.frozenChallengePeriod
        );
    }
}

contract PrimeProtocolInvariants is StdInvariant, Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    MockERC721 internal agiType;
    MockENSJobPages internal ensHookOk;
    MockENSJobPagesMalformed internal ensHookMalformed;
    HookGasBurner internal ensHookGasBurner;
    PrimeProtocolHandler internal handler;

    function setUp() external {
        token = new MockERC20();
        address zero;
        bytes32[4] memory rootNodes;
        bytes32[2] memory merkleRoots;
        manager = new AGIJobManagerPrimeHarness(address(token), "ipfs://base", zero, zero, rootNodes, merkleRoots);
        discovery = new AGIJobDiscoveryPrimeHarness(address(manager));
        agiType = new MockERC721();
        ensHookOk = new MockENSJobPages();
        ensHookMalformed = new MockENSJobPagesMalformed();
        ensHookGasBurner = new HookGasBurner();
        handler =
            new PrimeProtocolHandler(token, manager, discovery, agiType, ensHookOk, ensHookMalformed, ensHookGasBurner);
        targetContract(address(handler));
    }

    function _sumDiscoveryClaimable() internal view returns (uint256 total) {
        uint256 len = handler.trackedActorsLength();
        for (uint256 i = 0; i < len; ++i) {
            total += discovery.claimable(handler.trackedActors(i));
        }
    }

    function _discoveryLocked() internal view returns (uint256 total) {
        for (uint256 procurementId = 0; procurementId < discovery.nextProcurementId(); ++procurementId) {
            if (!discovery.procurementExists(procurementId)) continue;
            address[] memory applicants = discovery.procurementApplicants(procurementId);
            for (uint256 i = 0; i < applicants.length; ++i) {
                (,,,, uint256 lockedStake,,,,,,) = discovery.applicationView(procurementId, applicants[i]);
                total += lockedStake;
            }
            address[] memory finalists = discovery.procurementFinalists(procurementId);
            for (uint256 i = 0; i < finalists.length; ++i) {
                address[] memory scoreVals = discovery.scoreValidatorsList(procurementId, finalists[i]);
                for (uint256 j = 0; j < scoreVals.length; ++j) {
                    (,,, uint256 bond) = discovery.scoreCommitView(procurementId, finalists[i], scoreVals[j]);
                    total += bond;
                }
            }
        }
    }

    function invariant_managerSolventAgainstLockedBuckets() external view {
        uint256 locked = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds()
            + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), locked, "manager balance below locked buckets");
    }

    function invariant_discoverySolventAgainstObservedLocksAndClaimable() external view {
        uint256 locked = _discoveryLocked();
        uint256 claimableSum = _sumDiscoveryClaimable();
        assertGe(
            token.balanceOf(address(discovery)),
            locked + claimableSum,
            "discovery balance below observed locks+claimable"
        );
    }

    function invariant_noClaimableDriftBelowGhostLowerBound() external view {
        assertGe(
            _sumDiscoveryClaimable(),
            handler.totalClaimableLowerBound(),
            "claimable sum drifted below observed lower bound"
        );
        assertGe(
            _discoveryLocked(),
            handler.totalDiscoveryLockedLowerBound(),
            "locked state drifted below observed lower bound"
        );
    }

    function invariant_managerStateMachineAndSnapshotsStayCoherent() external view {
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            _assertManagerJobState(jobId);
        }
    }

    function _assertManagerJobState(uint256 jobId) internal view {
        (,, address disputeInitiator) = manager.jobActors(jobId);
        (
            ,
            address assignedAgent,,,,
            uint256 disputeBondAmount,
            uint256 validatorBondAmount,
            uint256 agentBondAmount,
            uint256 voteQuorumSnapshot,
            uint256 approvalsSnapshot,
            uint256 disapprovalsSnapshot,
            uint256 slashBpsSnapshot,,,
            uint32 validatorApprovals,
            uint32 validatorDisapprovals,
            uint64 completionRequestedAt,
            uint64 disputedAt,
            uint64 validatorApprovedAt,
            uint64 completionReviewSnapshot,
            uint64 disputeReviewSnapshot,
            uint64 challengeSnapshot,,
            bool completed,
            bool completionRequested,
            bool disputed,
            bool expired,
            bool escrowReleased,
            bool validatorApproved
        ) = manager.jobView(jobId);

        assertFalse(completed && expired, "job both completed and expired");
        assertFalse(completed && disputed, "job both completed and disputed");
        assertEq(
            uint256(manager.jobValidatorsLength(jobId)),
            uint256(validatorApprovals + validatorDisapprovals),
            "validator count drift"
        );
        if (assignedAgent == address(0)) assertEq(agentBondAmount, 0, "unassigned job kept agent bond");
        if (!disputed) assertEq(disputeBondAmount, 0, "non-disputed job kept dispute bond");
        if (disputed) {
            assertTrue(disputeInitiator != address(0), "disputed job missing initiator");
            assertGt(disputedAt, 0, "disputed job missing timestamp");
        }
        if (validatorBondAmount == 0) assertEq(manager.jobValidatorsLength(jobId), 0, "validator bond/list drift");
        if (validatorApproved) {
            assertTrue(validatorApprovedAt > 0, "approved job missing approval timestamp");
            assertTrue(completionRequested, "approved job missing completion request");
        }
        if (completionRequested) {
            assertTrue(completionRequestedAt > 0, "completion request missing timestamp");
            assertGt(completionReviewSnapshot, 0, "completion review snapshot missing");
            assertGt(disputeReviewSnapshot, 0, "dispute review snapshot missing");
            assertGt(challengeSnapshot, 0, "challenge snapshot missing");
            (
                uint256 ghostVoteQuorum,
                uint256 ghostApprovals,
                uint256 ghostDisapprovals,
                uint256 ghostSlashBps,
                uint256 ghostCompletionRequestedAt,
                uint256 ghostCompletionReview,
                uint256 ghostDisputeReview,
                uint256 ghostChallengePeriod
            ) = handler.ghostJobSnapshot(jobId);
            assertEq(voteQuorumSnapshot, ghostVoteQuorum, "vote quorum snapshot mutated");
            assertEq(approvalsSnapshot, ghostApprovals, "approval snapshot mutated");
            assertEq(disapprovalsSnapshot, ghostDisapprovals, "disapproval snapshot mutated");
            assertEq(slashBpsSnapshot, ghostSlashBps, "slash snapshot mutated");
            assertEq(completionRequestedAt, ghostCompletionRequestedAt, "completion timestamp mutated");
            assertEq(completionReviewSnapshot, ghostCompletionReview, "completion review snapshot mutated");
            assertEq(disputeReviewSnapshot, ghostDisputeReview, "dispute review snapshot mutated");
            assertEq(challengeSnapshot, ghostChallengePeriod, "challenge snapshot mutated");
        }
        if (escrowReleased) assertTrue(completed || expired, "escrow released on non-terminal job");
    }

    function invariant_discoveryStateMachineAndHelperViewsStayTruthful() external view {
        for (uint256 procurementId = 0; procurementId < discovery.nextProcurementId(); ++procurementId) {
            if (!discovery.procurementExists(procurementId)) continue;
            _assertDiscoveryProcurement(procurementId);
        }
    }

    function _assertDiscoveryProcurement(uint256 procurementId) internal view {
        (
            address employer,,,
            uint64 commitDeadline,
            uint64 revealDeadline,
            uint64 finalistAcceptDeadline,
            uint64 trialDeadline,
            uint64 scoreCommitDeadline,
            uint64 scoreRevealDeadline,,,
            uint8 finalistCount,,
            uint8 maxValidatorRevealsPerFinalist,,,
            uint256 stipendPerFinalist,
            uint256 validatorRewardPerReveal,
            uint256 validatorScoreBond,
            bool shortlistFinalized,
            bool winnerFinalized,
            bool cancelled,
            uint256 applicantsLength,
            uint256 finalistsLength
        ) = discovery.procurementView(procurementId);
        employer;
        assertLt(commitDeadline, revealDeadline, "commit/reveal ordering broken");
        assertLe(revealDeadline, finalistAcceptDeadline, "reveal/finalist ordering broken");
        assertLe(finalistAcceptDeadline, trialDeadline, "finalist/trial ordering broken");
        assertLt(trialDeadline, scoreCommitDeadline, "trial/score-commit ordering broken");
        assertLt(scoreCommitDeadline, scoreRevealDeadline, "score windows ordering broken");
        assertLe(finalistsLength, uint256(finalistCount), "too many finalists");
        assertLe(applicantsLength, discovery.MAX_APPLICANTS(), "too many applicants");
        if (cancelled) {
            assertFalse(discovery.isWinnerFinalizable(procurementId), "cancelled procurement still finalizable");
        }
        if (winnerFinalized) assertTrue(shortlistFinalized, "winner finalized before shortlist");

        address[] memory finalists = discovery.procurementFinalists(procurementId);
        uint256 finalistClaimableEnvelope;
        for (uint256 i = 0; i < finalists.length; ++i) {
            (
                bool revealed,
                bool shortlisted,
                bool finalistAccepted,
                bool trialSubmitted,,,,,
                uint256 trialScoreBps,
                uint256 compositeScoreBps,
                bool everPromoted
            ) = discovery.applicationView(procurementId, finalists[i]);
            assertTrue(shortlisted, "finalist not marked shortlisted");
            if (finalistAccepted) assertTrue(shortlisted, "accepted finalist not shortlisted");
            if (trialSubmitted) assertTrue(finalistAccepted, "trial without accept");
            if (trialScoreBps > 0) assertTrue(trialSubmitted, "trial score without trial");
            if (everPromoted) {
                assertTrue(compositeScoreBps > 0 || winnerFinalized, "promoted finalist missing score or finalization");
            }
            if (revealed) {}
            finalistClaimableEnvelope += discovery.claimable(finalists[i]);
        }
        uint256 stipendBudget = uint256(finalistCount) * stipendPerFinalist;
        uint256 rewardBudget =
            uint256(finalistCount) * uint256(maxValidatorRevealsPerFinalist) * validatorRewardPerReveal;
        assertLe(
            finalistClaimableEnvelope,
            stipendBudget + validatorScoreBond * finalistsLength + rewardBudget,
            "finalist claim envelope overrun"
        );

        string memory next = discovery.nextActionForProcurement(procurementId);
        if (keccak256(bytes(next)) == keccak256(bytes("FW"))) {
            assertTrue(discovery.isWinnerFinalizable(procurementId), "FW helper lied about winner finalization");
        }
    }

    function invariant_fallbackPromotionAndNFTIssuanceRemainOneShot() external view {
        AGIJobCompletionNFT nft = AGIJobCompletionNFT(manager.completionNFTAddress());
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            (,,,,,,,,,,,,,,,,,,,,,,, bool completed,, bool disputed, bool expired,,) = manager.jobView(jobId);
            if (completed && !disputed && !expired) {
                // NFT mint count can lag only if completion reverted, which cannot happen after completed=true.
                assertGe(nft.nextTokenId(), 1, "completed path minted no completion NFT");
            }
        }

        for (uint256 procurementId = 0; procurementId < discovery.nextProcurementId(); ++procurementId) {
            if (!discovery.procurementExists(procurementId)) continue;
            address[] memory finalists = discovery.procurementFinalists(procurementId);
            uint256 promotedCount;
            for (uint256 i = 0; i < finalists.length; ++i) {
                (,,,,,,,,,, bool everPromoted) = discovery.applicationView(procurementId, finalists[i]);
                if (everPromoted) promotedCount++;
            }
            assertLe(promotedCount, finalists.length, "promotion counter overflow");
        }
    }
}
