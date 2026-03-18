// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "forge-test/harness/prime/AGIJobManagerPrimeHarness.sol";
import "forge-test/harness/prime/AGIJobDiscoveryPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";
import "contracts/test/HostileEnsJobPages.sol";
import "contracts/AGIJobDiscoveryPrime.sol";

contract PrimeInvariantHandler is Test {
    MockERC20 public token;
    AGIJobManagerPrimeHarness public manager;
    AGIJobDiscoveryPrimeHarness public discovery;
    HostileEnsJobPages public hostilePages;

    address public owner;
    address public moderator = address(0xBEEF);
    address public pendingOwner = address(0xCAFE);

    address[] public employers;
    address[] public agents;
    address[] public validators;

    mapping(uint256 => uint64) public disputedAtSnapshot;
    mapping(uint256 => address) public selectionAgentSnapshot;
    mapping(uint256 => uint64) public selectionExpirySnapshot;
    mapping(uint256 => uint64) public checkpointDeadlineSnapshot;
    mapping(uint256 => bytes32) public perJobRootSnapshot;
    mapping(uint256 => bool) public winnerFinalizedSeen;
    mapping(uint256 => address) public promotedWinner;

    constructor(
        MockERC20 _token,
        AGIJobManagerPrimeHarness _manager,
        AGIJobDiscoveryPrimeHarness _discovery,
        HostileEnsJobPages _hostilePages
    ) {
        token = _token;
        manager = _manager;
        discovery = _discovery;
        hostilePages = _hostilePages;
        owner = manager.owner();

        employers.push(address(0x1001));
        employers.push(address(0x1002));
        employers.push(address(0x1003));
        agents.push(address(0x2001));
        agents.push(address(0x2002));
        agents.push(address(0x2003));
        validators.push(address(0x3001));
        validators.push(address(0x3002));
        validators.push(address(0x3003));

        MockERC721 agiType = new MockERC721();

        vm.startPrank(owner);
        manager.addOrUpdateAGIType(address(agiType), 65);
        manager.addModerator(moderator);
        manager.setSettlementPaused(false);
        manager.unpause();
        manager.setVoteQuorum(1);
        manager.setRequiredValidatorApprovals(1);
        manager.setRequiredValidatorDisapprovals(1);
        manager.setDiscoveryModule(address(discovery));
        manager.setEnsJobPages(address(hostilePages));
        discovery.unpause();
        discovery.setIntakePaused(false);
        vm.stopPrank();

        for (uint256 i = 0; i < employers.length; ++i) {
            token.mint(employers[i], 2_000_000 ether);
            vm.prank(employers[i]); token.approve(address(manager), type(uint256).max);
            vm.prank(employers[i]); token.approve(address(discovery), type(uint256).max);
        }
        for (uint256 i = 0; i < agents.length; ++i) {
            token.mint(agents[i], 2_000_000 ether);
            agiType.mint(agents[i]);
            vm.prank(owner); manager.addAdditionalAgent(agents[i]);
            vm.prank(agents[i]); token.approve(address(manager), type(uint256).max);
            vm.prank(agents[i]); token.approve(address(discovery), type(uint256).max);
        }
        for (uint256 i = 0; i < validators.length; ++i) {
            token.mint(validators[i], 2_000_000 ether);
            vm.prank(owner); manager.addAdditionalValidator(validators[i]);
            vm.prank(validators[i]); token.approve(address(manager), type(uint256).max);
            vm.prank(validators[i]); token.approve(address(discovery), type(uint256).max);
        }
        token.mint(moderator, 100 ether);
        vm.prank(moderator); token.approve(address(manager), type(uint256).max);
    }

    function _employer(uint256 seed) internal view returns (address) { return employers[bound(seed, 0, employers.length - 1)]; }
    function _agent(uint256 seed) internal view returns (address) { return agents[bound(seed, 0, agents.length - 1)]; }
    function _validator(uint256 seed) internal view returns (address) { return validators[bound(seed, 0, validators.length - 1)]; }

    function actorList() external view returns (address[] memory out) {
        out = new address[](1 + employers.length + agents.length + validators.length + 2);
        uint256 idx;
        out[idx++] = moderator;
        for (uint256 i = 0; i < employers.length; ++i) out[idx++] = employers[i];
        for (uint256 i = 0; i < agents.length; ++i) out[idx++] = agents[i];
        for (uint256 i = 0; i < validators.length; ++i) out[idx++] = validators[i];
        out[idx++] = owner;
        out[idx++] = pendingOwner;
    }

    function _rememberJob(uint256 jobId) internal {
        if (jobId >= manager.nextJobId()) return;
        uint64 disputedAt = manager.jobDisputedAt(jobId);
        if (disputedAt != 0 && disputedAtSnapshot[jobId] == 0) disputedAtSnapshot[jobId] = disputedAt;
        address selected = manager.jobSelectedAgent(jobId);
        uint64 expiry = manager.jobSelectionExpiresAt(jobId);
        uint64 checkpoint = manager.jobCheckpointDeadline(jobId);
        bytes32 root = manager.jobPerJobAgentRoot(jobId);
        if (selectionAgentSnapshot[jobId] == address(0) && (selected != address(0) || expiry != 0 || checkpoint != 0 || root != bytes32(0))) {
            selectionAgentSnapshot[jobId] = selected;
            selectionExpirySnapshot[jobId] = expiry;
            checkpointDeadlineSnapshot[jobId] = checkpoint;
            perJobRootSnapshot[jobId] = root;
        }
    }

    function _rememberProcurement(uint256 procurementId) internal {
        if (procurementId >= discovery.nextProcurementId()) return;
        if (discovery.procurementWinnerFinalized(procurementId)) {
            winnerFinalizedSeen[procurementId] = true;
            promotedWinner[procurementId] = manager.jobAssignedAgent(discovery.procurementJobIdView(procurementId));
        }
    }

    function _warp(uint256 seed, uint256 maxDelta) internal { vm.warp(block.timestamp + bound(seed, 0, maxDelta)); }

    function createManagerJob(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed) external {
        vm.prank(_employer(employerSeed));
        try manager.createJob("ipfs://spec", bound(payoutSeed, 1 ether, 120 ether), bound(durationSeed, 4 hours, 10 days), "prime") returns (uint256 jobId) {
            _rememberJob(jobId);
        } catch {}
    }

    function createProcurement(uint256 employerSeed, uint256 timeSeed, uint256 budgetSeed) external {
        AGIJobDiscoveryPrime.PremiumJobParams memory job = AGIJobDiscoveryPrime.PremiumJobParams({
            jobSpecURI: "ipfs://spec",
            payout: bound(budgetSeed, 10 ether, 100 ether),
            duration: bound(timeSeed, 1 days, 10 days),
            details: "prime"
        });
        uint64 base = uint64(block.timestamp + 1);
        AGIJobDiscoveryPrime.ProcurementParams memory p = AGIJobDiscoveryPrime.ProcurementParams({
            commitDeadline: base + 1 days,
            revealDeadline: base + 2 days,
            finalistAcceptDeadline: base + 3 days,
            trialDeadline: base + 4 days,
            scoreCommitDeadline: base + 5 days,
            scoreRevealDeadline: base + 6 days,
            selectedAcceptanceWindow: 1 days,
            checkpointWindow: 1 days,
            finalistCount: uint8(bound(budgetSeed >> 16, 1, 2)),
            minValidatorReveals: 1,
            maxValidatorRevealsPerFinalist: 2,
            historicalWeightBps: 5000,
            trialWeightBps: 5000,
            minReputation: 0,
            applicationStake: bound(budgetSeed >> 32, 0, 3 ether),
            finalistStakeTotal: bound(budgetSeed >> 48, 1 ether, 4 ether),
            stipendPerFinalist: bound(budgetSeed >> 64, 1 ether, 3 ether),
            validatorRewardPerReveal: bound(budgetSeed >> 80, 0.1 ether, 1 ether),
            validatorScoreBond: bound(budgetSeed >> 96, 0.1 ether, 1 ether)
        });
        vm.prank(_employer(employerSeed));
        try discovery.createPremiumJobWithDiscovery(job, p) returns (uint256 jobId, uint256 procurementId) {
            _rememberJob(jobId);
            _rememberProcurement(procurementId);
        } catch {}
    }

    function managerAction(uint256 jobSeed, uint256 actorSeed, uint256 warpSeed, uint8 action) external {
        if (manager.nextJobId() == 0) return;
        uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
        if (action % 6 == 0) {
            vm.prank(_agent(actorSeed));
            try manager.applyForJob(jobId, "", new bytes32[](0), new bytes32[](0)) { _rememberJob(jobId); } catch {}
        } else if (action % 6 == 1) {
            vm.prank(_agent(actorSeed));
            try manager.requestJobCompletion(jobId, "ipfs://done") { _rememberJob(jobId); } catch {}
        } else if (action % 6 == 2) {
            vm.prank(_validator(actorSeed));
            try manager.validateJob(jobId, "", new bytes32[](0)) { _rememberJob(jobId); } catch {}
        } else if (action % 6 == 3) {
            vm.prank(_validator(actorSeed));
            try manager.disapproveJob(jobId, "", new bytes32[](0)) { _rememberJob(jobId); } catch {}
        } else if (action % 6 == 4) {
            _warp(warpSeed, 30 days);
            try manager.finalizeJob(jobId) { _rememberJob(jobId); } catch {}
        } else {
            _warp(warpSeed, 30 days);
            try manager.expireJob(jobId) { _rememberJob(jobId); } catch {}
        }
    }

    function disputeAndAdmin(uint256 jobSeed, uint256 actionSeed, uint256 warpSeed) external {
        if (manager.nextJobId() != 0) {
            uint256 jobId = bound(jobSeed, 0, manager.nextJobId() - 1);
            _warp(warpSeed, 15 days);
            if (actionSeed % 3 == 0) {
                address employer = manager.jobEmployer(jobId);
                if (employer != address(0)) {
                    vm.prank(employer);
                    try manager.disputeJob(jobId) { _rememberJob(jobId); } catch {}
                }
            } else if (actionSeed % 3 == 1) {
                vm.prank(moderator);
                try manager.resolveDisputeWithCode(jobId, 1, "mod") { _rememberJob(jobId); } catch {}
            } else {
                vm.prank(owner);
                try manager.resolveStaleDispute(jobId, true) { _rememberJob(jobId); } catch {}
            }
        }

        vm.startPrank(owner);
        if (actionSeed % 6 == 0) manager.pause();
        else if (actionSeed % 6 == 1) manager.unpause();
        else if (actionSeed % 6 == 2) manager.setSettlementPaused(actionSeed % 2 == 0);
        else if (actionSeed % 6 == 3) discovery.pause();
        else if (actionSeed % 6 == 4) discovery.unpause();
        else hostilePages.setMode(HostileEnsJobPages.Mode(bound(actionSeed, 0, 3)));
        vm.stopPrank();
    }

    function discoveryAction(uint256 procurementSeed, uint256 agentSeed, uint256 validatorSeed, uint256 warpSeed, uint8 action) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 procurementId = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address agent = _agent(agentSeed);
        string memory appUri = "ipfs://app";
        bytes32 salt = keccak256(abi.encodePacked(procurementId, agent));
        bytes32 commitment = keccak256(abi.encodePacked(procurementId, agent, appUri, salt));
        if (action % 8 == 0) {
            vm.prank(agent);
            try discovery.commitApplication(procurementId, commitment, "", new bytes32[](0)) { _rememberProcurement(procurementId); } catch {}
        } else if (action % 8 == 1) {
            _warp(warpSeed, 3 days);
            vm.prank(agent);
            try discovery.revealApplication(procurementId, "", new bytes32[](0), salt, appUri) { _rememberProcurement(procurementId); } catch {}
        } else if (action % 8 == 2) {
            _warp(warpSeed, 4 days);
            try discovery.finalizeShortlist(procurementId) { _rememberProcurement(procurementId); } catch {}
        } else if (action % 8 == 3) {
            vm.prank(agent);
            try discovery.acceptFinalist(procurementId) { _rememberProcurement(procurementId); } catch {}
        } else if (action % 8 == 4) {
            vm.prank(agent);
            try discovery.submitTrial(procurementId, "ipfs://trial") { _rememberProcurement(procurementId); } catch {}
        } else if (action % 8 == 5) {
            address validator = _validator(validatorSeed);
            bytes32 scoreSalt = keccak256(abi.encodePacked(procurementId, agent, validator));
            bytes32 scoreCommitment = keccak256(abi.encodePacked(procurementId, agent, validator, uint8(50), scoreSalt));
            _warp(warpSeed, 6 days);
            vm.prank(validator);
            try discovery.commitFinalistScore(procurementId, agent, scoreCommitment, "", new bytes32[](0)) { _rememberProcurement(procurementId); } catch {}
        } else if (action % 8 == 6) {
            address validator = _validator(validatorSeed);
            bytes32 scoreSalt = keccak256(abi.encodePacked(procurementId, agent, validator));
            _warp(warpSeed, 7 days);
            vm.prank(validator);
            try discovery.revealFinalistScore(procurementId, agent, 50, scoreSalt, "", new bytes32[](0)) { _rememberProcurement(procurementId); } catch {}
        } else {
            _warp(warpSeed, 12 days);
            try discovery.advanceProcurement(procurementId) { _rememberProcurement(procurementId); } catch {}
            try discovery.finalizeWinner(procurementId) { _rememberProcurement(procurementId); } catch {}
            try discovery.promoteFallbackFinalist(procurementId) { _rememberProcurement(procurementId); } catch {}
        }
    }
}

contract PrimeArchitectureInvariants is StdInvariant, Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    HostileEnsJobPages internal hostilePages;
    PrimeInvariantHandler internal handler;

    function setUp() external {
        token = new MockERC20();
        bytes32[4] memory rootNodes;
        bytes32[2] memory merkleRoots;
        manager = new AGIJobManagerPrimeHarness(address(token), "", address(0), address(0), rootNodes, merkleRoots);
        discovery = new AGIJobDiscoveryPrimeHarness(address(manager));
        hostilePages = new HostileEnsJobPages();
        handler = new PrimeInvariantHandler(token, manager, discovery, hostilePages);
        targetContract(address(handler));
    }

    function _actors() internal view returns (address[] memory) { return handler.actorList(); }

    function invariant_managerTokenConservation() external view {
        uint256 locked = manager.lockedEscrow() + manager.lockedAgentBonds() + manager.lockedValidatorBonds() + manager.lockedDisputeBonds();
        assertGe(token.balanceOf(address(manager)), locked);
    }

    function invariant_discoveryTokenConservation() external view {
        uint256 locked;
        for (uint256 procurementId = 0; procurementId < discovery.nextProcurementId(); ++procurementId) {
            uint256 applicantCount = discovery.procurementApplicantsLength(procurementId);
            for (uint256 i = 0; i < applicantCount; ++i) locked += discovery.applicationLockedStake(procurementId, discovery.procurementApplicants(procurementId)[i]);
            uint256 finalistCount = discovery.procurementFinalistsLength(procurementId);
            for (uint256 i = 0; i < finalistCount; ++i) {
                address finalist = discovery.procurementFinalists(procurementId)[i];
                uint256 validatorCount = discovery.scoreValidatorsLength(procurementId, finalist);
                for (uint256 j = 0; j < validatorCount; ++j) {
                    (, bool revealed,, uint256 bond) = discovery.scoreCommitView(procurementId, finalist, discovery.scoreValidators(procurementId, finalist, j));
                    if (!revealed && !discovery.procurementWinnerFinalized(procurementId) && !discovery.procurementCancelled(procurementId)) locked += bond;
                }
            }
        }
        uint256 claimableTotal;
        address[] memory actors = _actors();
        for (uint256 i = 0; i < actors.length; ++i) claimableTotal += discovery.claimable(actors[i]);
        assertGe(token.balanceOf(address(discovery)), locked + claimableTotal);
    }

    function invariant_managerStateMachine() external view {
        uint256 activeTracked;
        address[] memory actors = _actors();
        for (uint256 i = 0; i < actors.length; ++i) activeTracked += manager.activeJobsByAgent(actors[i]);

        uint256 activeCount;
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (!manager.jobExists(jobId)) continue;
            assertFalse(manager.jobCompleted(jobId) && manager.jobExpired(jobId));
            assertFalse(manager.jobCompleted(jobId) && manager.jobDisputed(jobId));
            assertEq(manager.jobValidatorsLength(jobId), uint256(manager.jobValidatorApprovals(jobId)) + uint256(manager.jobValidatorDisapprovals(jobId)));
            if (handler.disputedAtSnapshot(jobId) != 0) assertEq(manager.jobDisputedAt(jobId), handler.disputedAtSnapshot(jobId));
            if (handler.selectionExpirySnapshot(jobId) != 0 || handler.selectionAgentSnapshot(jobId) != address(0) || handler.perJobRootSnapshot(jobId) != bytes32(0)) {
                assertEq(manager.jobSelectedAgent(jobId), handler.selectionAgentSnapshot(jobId));
                assertEq(manager.jobSelectionExpiresAt(jobId), handler.selectionExpirySnapshot(jobId));
                assertEq(manager.jobCheckpointDeadline(jobId), handler.checkpointDeadlineSnapshot(jobId));
                assertEq(manager.jobPerJobAgentRoot(jobId), handler.perJobRootSnapshot(jobId));
            }
            address assigned = manager.jobAssignedAgent(jobId);
            if (assigned != address(0) && !manager.jobCompleted(jobId) && !manager.jobExpired(jobId) && !manager.jobEscrowReleased(jobId)) activeCount += 1;
            if (!manager.jobExists(jobId)) {
                assertEq(manager.jobAgentBondAmount(jobId), 0);
                assertEq(manager.jobValidatorBondAmount(jobId), 0);
                assertEq(manager.jobDisputeBondAmount(jobId), 0);
            }
        }
        assertEq(activeTracked, activeCount);
    }

    function invariant_discoveryStateMachine() external view {
        for (uint256 procurementId = 0; procurementId < discovery.nextProcurementId(); ++procurementId) {
            uint256 finalistCount = discovery.procurementFinalistsLength(procurementId);
            assertLe(finalistCount, discovery.procurementFinalistCount(procurementId));
            assertLe(discovery.procurementMinValidatorReveals(procurementId), discovery.procurementMaxValidatorReveals(procurementId));
            if (discovery.procurementWinnerFinalized(procurementId)) assertFalse(discovery.procurementCancelled(procurementId));
            if (discovery.procurementCancelled(procurementId)) assertFalse(discovery.procurementWinnerFinalized(procurementId));
            for (uint256 i = 0; i < finalistCount; ++i) {
                address finalist = discovery.procurementFinalists(procurementId)[i];
                assertTrue(discovery.applicationShortlisted(procurementId, finalist));
                if (discovery.applicationFinalistAccepted(procurementId, finalist)) assertTrue(discovery.applicationShortlisted(procurementId, finalist));
                if (discovery.applicationTrialSubmitted(procurementId, finalist)) assertTrue(discovery.applicationFinalistAccepted(procurementId, finalist));
                if (discovery.applicationEverPromoted(procurementId, finalist) && handler.promotedWinner(procurementId) != address(0)) {
                    assertEq(finalist, handler.promotedWinner(procurementId));
                }
            }
            if (discovery.procurementWinnerFinalized(procurementId) || discovery.procurementCancelled(procurementId)) {
                uint256 applicantCount = discovery.procurementApplicantsLength(procurementId);
                for (uint256 i = 0; i < applicantCount; ++i) {
                    assertEq(discovery.applicationLockedStake(procurementId, discovery.procurementApplicants(procurementId)[i]), 0);
                }
            }
        }
    }

    function invariant_pauseClockAndHelperViews() external view {
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) {
            if (manager.jobExists(jobId)) assertLe(manager.effectiveTimestampForJob(jobId), block.timestamp);
        }
        for (uint256 procurementId = 0; procurementId < discovery.nextProcurementId(); ++procurementId) {
            assertLe(discovery.effectiveTimestampForProcurement(procurementId), block.timestamp);
            assertGt(bytes(discovery.nextActionForProcurement(procurementId)).length, 0);
        }
    }

    function invariant_completionNFTCannotOutrunCompletion() external view {
        uint256 completedJobs;
        for (uint256 jobId = 0; jobId < manager.nextJobId(); ++jobId) if (manager.jobExists(jobId) && manager.jobCompleted(jobId)) completedJobs += 1;
        assertLe(manager.completionNFTNextTokenId(), completedJobs);
    }
}
