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

contract PrimePauseDeadlineHandler is Test {
    AGIJobManagerPrimeHarness public manager;
    AGIJobDiscoveryPrimeHarness public discovery;
    MockERC20 public token;

    address public owner;
    address[] public employers;
    address[] public agents;
    address[] public validators;

    mapping(uint256 => uint64) public creationPauseBaseline;
    mapping(uint256 => uint256) public frozenEffectiveAtPause;
    mapping(uint256 => bool) public existedAtCurrentPause;

    uint64 public maxObservedPausedSeconds;
    uint256 internal constant MAX_PROCUREMENTS = 24;
    uint256 internal constant MAX_JOBS = 24;

    constructor(AGIJobManagerPrimeHarness _manager, AGIJobDiscoveryPrimeHarness _discovery, MockERC20 _token) {
        manager = _manager;
        discovery = _discovery;
        token = _token;
        owner = manager.owner();

        MockERC721 agiType = new MockERC721();
        vm.startPrank(owner);
        manager.setDiscoveryModule(address(discovery));
        manager.setPremiumReputationThreshold(0);
        manager.setRequiredValidatorApprovals(1);
        manager.setRequiredValidatorDisapprovals(1);
        manager.setVoteQuorum(1);
        manager.setChallengePeriodAfterApproval(1 days);
        vm.stopPrank();

        for (uint256 i = 0; i < 3; ++i) {
            address employer = address(uint160(0x5100 + i));
            address agent = address(uint160(0x6100 + i));
            address validator = address(uint160(0x7100 + i));
            employers.push(employer);
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

        vm.prank(owner);
        manager.addOrUpdateAGIType(address(agiType), 80);
        maxObservedPausedSeconds = discovery.pausedSecondsAccumulated();
    }

    function _refreshPauseObservation() internal {
        uint64 pausedNow = discovery.pausedSecondsNowView();
        if (pausedNow > maxObservedPausedSeconds) maxObservedPausedSeconds = pausedNow;
    }

    function _recordPauseFreeze() internal {
        uint256 count = discovery.nextProcurementId();
        for (uint256 pid = 0; pid < count; ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            existedAtCurrentPause[pid] = true;
            frozenEffectiveAtPause[pid] = discovery.effectiveTimestampView(pid);
        }
    }

    function warp(uint256 seed) external {
        uint256 step = bound(seed, 0, 10);
        uint256 beforeCount = discovery.nextProcurementId();
        if (step == 0) vm.warp(block.timestamp + 1);
        else if (step == 1) vm.warp(block.timestamp + 2);
        else if (step == 2) vm.warp(block.timestamp + 19);
        else if (step == 3) vm.warp(block.timestamp + 20);
        else if (step == 4) vm.warp(block.timestamp + 21);
        else if (step == 5) vm.warp(block.timestamp + 39);
        else if (step == 6) vm.warp(block.timestamp + 40);
        else if (step == 7) vm.warp(block.timestamp + 41);
        else if (step == 8) vm.warp(block.timestamp + 1 days);
        else if (step == 9) vm.warp(block.timestamp + 7 days);
        else vm.warp(block.timestamp + 30 days);

        if (discovery.paused()) {
            for (uint256 pid = 0; pid < beforeCount; ++pid) {
                if (!existedAtCurrentPause[pid]) continue;
                assertEq(
                    discovery.effectiveTimestampView(pid),
                    frozenEffectiveAtPause[pid],
                    "effective time moved while discovery paused"
                );
            }
        }
        _refreshPauseObservation();
    }

    function togglePauses(uint256 seed) external {
        vm.startPrank(owner);
        manager.setSettlementPaused((seed & 1) == 1);
        if ((seed & 2) == 2) manager.pause();
        else manager.unpause();

        if ((seed & 4) == 4) {
            if (!discovery.paused()) {
                discovery.pause();
                _recordPauseFreeze();
            }
        } else if (discovery.paused()) {
            discovery.unpause();
        }
        discovery.setIntakePaused((seed & 8) == 8);
        vm.stopPrank();
        _refreshPauseObservation();
    }

    function createProcurement(uint256 employerSeed, uint256 payoutSeed, uint256 durationSeed, uint256 cfgSeed)
        external
    {
        if (manager.nextJobId() >= MAX_JOBS || discovery.nextProcurementId() >= MAX_PROCUREMENTS) return;
        address employer = employers[bound(employerSeed, 0, employers.length - 1)];
        uint64 start = uint64(block.timestamp + 10);
        AGIJobDiscoveryPrime.PremiumJobParams memory premium = AGIJobDiscoveryPrime.PremiumJobParams({
            jobSpecURI: "ipfs://prime",
            payout: bound(payoutSeed, 5 ether, 50 ether),
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

        uint64 pausedAtCreate = discovery.pausedSecondsNowView();
        vm.prank(employer);
        try discovery.createPremiumJobWithDiscovery(premium, proc) returns (uint256, uint256 pid) {
            creationPauseBaseline[pid] = pausedAtCreate;
            assertEq(discovery.procurementPauseBaselineView(pid), pausedAtCreate, "bad pause baseline at create");
            if (discovery.paused()) {
                existedAtCurrentPause[pid] = false;
                frozenEffectiveAtPause[pid] = 0;
            }
        } catch {}
        _refreshPauseObservation();
    }

    function commitRevealAdvance(uint256 procurementSeed, uint256 actorSeed, uint8 scoreSeed, uint8 mode) external {
        if (discovery.nextProcurementId() == 0) return;
        uint256 pid = bound(procurementSeed, 0, discovery.nextProcurementId() - 1);
        address agent = agents[bound(actorSeed, 0, agents.length - 1)];
        address validator = validators[bound(actorSeed >> 8, 0, validators.length - 1)];
        address finalist = agent;
        bytes32 salt = keccak256(abi.encodePacked(pid, agent, validator, mode));
        uint8 action = uint8(mode % 9);

        if (action == 0) {
            vm.prank(agent);
            try discovery.commitApplication(
                pid, keccak256(abi.encodePacked(pid, agent, "ipfs://app", salt)), "", new bytes32[](0)
            ) {}
                catch {}
        } else if (action == 1) {
            vm.prank(agent);
            try discovery.revealApplication(pid, "", new bytes32[](0), salt, "ipfs://app") {} catch {}
        } else if (action == 2) {
            try discovery.finalizeShortlist(pid) {} catch {}
        } else if (action == 3) {
            vm.prank(agent);
            try discovery.acceptFinalist(pid) {} catch {}
        } else if (action == 4) {
            vm.prank(agent);
            try discovery.submitTrial(pid, "ipfs://trial") {} catch {}
        } else if (action == 5) {
            vm.prank(validator);
            try discovery.commitFinalistScore(
                pid,
                finalist,
                keccak256(abi.encodePacked(pid, finalist, validator, uint8(bound(scoreSeed, 0, 100)), salt)),
                "",
                new bytes32[](0)
            ) {}
                catch {}
        } else if (action == 6) {
            vm.prank(validator);
            try discovery.revealFinalistScore(
                pid, finalist, uint8(bound(scoreSeed, 0, 100)), salt, "", new bytes32[](0)
            ) {}
                catch {}
        } else if (action == 7) {
            try discovery.advanceProcurement(pid) {} catch {}
        } else {
            try discovery.promoteFallbackFinalist(pid) {} catch {}
        }
        _refreshPauseObservation();
    }
}

contract PrimePauseDeadlineInvariants is StdInvariant, Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
    PrimePauseDeadlineHandler internal handler;

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
        handler = new PrimePauseDeadlineHandler(manager, discovery, token);
        targetContract(address(handler));
    }

    function invariant_pauseSecondsMonotonicAndBaselinesPinned() external view {
        uint64 pausedNow = discovery.pausedSecondsNowView();
        assertGe(pausedNow, handler.maxObservedPausedSeconds(), "paused seconds regressed");

        for (uint256 pid = 0; pid < discovery.nextProcurementId(); ++pid) {
            if (!discovery.procurementExists(pid)) continue;
            uint64 baseline = discovery.procurementPauseBaselineView(pid);
            assertEq(baseline, handler.creationPauseBaseline(pid), "creation baseline drifted");
            assertLe(baseline, pausedNow, "baseline exceeds paused seconds now");
        }
    }

    function invariant_effectiveTimestampFreezesDuringPause() external view {
        if (!discovery.paused()) return;
        for (uint256 pid = 0; pid < discovery.nextProcurementId(); ++pid) {
            if (!discovery.procurementExists(pid) || !handler.existedAtCurrentPause(pid)) continue;
            assertEq(
                discovery.effectiveTimestampView(pid),
                handler.frozenEffectiveAtPause(pid),
                "effective timestamp changed while paused"
            );
        }
    }

    function invariant_pauseCannotRetroactivelyMissTrackedDeadlines() external view {
        if (!discovery.paused()) return;
        for (uint256 pid = 0; pid < discovery.nextProcurementId(); ++pid) {
            if (!discovery.procurementExists(pid) || !handler.existedAtCurrentPause(pid)) continue;
            (
                ,,,,,,
                uint64 commitDeadline,
                uint64 revealDeadline,
                uint64 finalistAcceptDeadline,
                uint64 trialDeadline,
                uint64 scoreCommitDeadline,
                uint64 scoreRevealDeadline,,,,,,,,,
                uint256 effectiveNow
            ) = discovery.procurementView(pid);
            uint256 frozen = handler.frozenEffectiveAtPause(pid);
            assertEq(effectiveNow, frozen, "paused effective timestamp drifted");
            if (frozen <= commitDeadline) {
                assertLe(effectiveNow, commitDeadline, "commit deadline crossed during pause");
            }
            if (frozen <= revealDeadline) {
                assertLe(effectiveNow, revealDeadline, "reveal deadline crossed during pause");
            }
            if (frozen <= finalistAcceptDeadline) {
                assertLe(effectiveNow, finalistAcceptDeadline, "accept deadline crossed during pause");
            }
            if (frozen <= trialDeadline) assertLe(effectiveNow, trialDeadline, "trial deadline crossed during pause");
            if (frozen <= scoreCommitDeadline) {
                assertLe(effectiveNow, scoreCommitDeadline, "score commit deadline crossed during pause");
            }
            if (frozen <= scoreRevealDeadline) {
                assertLe(effectiveNow, scoreRevealDeadline, "score reveal deadline crossed during pause");
            }
        }
    }
}
