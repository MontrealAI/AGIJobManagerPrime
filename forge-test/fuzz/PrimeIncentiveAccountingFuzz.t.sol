// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-test/harness/AGIJobManagerPrimeHarness.sol";
import "forge-test/harness/AGIJobDiscoveryPrimeHarness.sol";
import "contracts/test/MockERC20.sol";
import "contracts/test/MockERC721.sol";
import "contracts/test/MockENS.sol";
import "contracts/test/MockNameWrapper.sol";

contract PrimeIncentiveAccountingFuzz is Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrimeHarness internal discovery;
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
        discovery = new AGIJobDiscoveryPrimeHarness(address(manager));
        manager.setDiscoveryModule(address(discovery));
        manager.setPremiumReputationThreshold(0);
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
            vm.prank(funded[i]);
            token.approve(address(discovery), type(uint256).max);
        }
    }

    function testFuzz_validatorRewardsStayWithinBudget(uint8 scoreA, uint8 scoreB, uint8 scoreC) external {
        uint64 start = uint64(block.timestamp + 10);
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
            minValidatorReveals: 2,
            maxValidatorRevealsPerFinalist: 3,
            historicalWeightBps: 3000,
            trialWeightBps: 7000,
            minReputation: 0,
            applicationStake: 1 ether,
            finalistStakeTotal: 2 ether,
            stipendPerFinalist: 1 ether,
            validatorRewardPerReveal: 1 ether,
            validatorScoreBond: 0.5 ether
        });

        vm.prank(employer);
        (, uint256 pid) = discovery.createPremiumJobWithDiscovery(premium, proc);
        bytes32 appSalt = keccak256("app");
        bytes32 appCommitment = keccak256(abi.encodePacked(pid, agent, "ipfs://app", appSalt));
        vm.prank(agent);
        discovery.commitApplication(pid, appCommitment, "", new bytes32[](0));
        vm.warp(proc.commitDeadline + 1);
        vm.prank(agent);
        discovery.revealApplication(pid, "", new bytes32[](0), appSalt, "ipfs://app");
        vm.warp(proc.revealDeadline + 1);
        discovery.finalizeShortlist(pid);
        vm.prank(agent);
        discovery.acceptFinalist(pid);
        vm.prank(agent);
        discovery.submitTrial(pid, "ipfs://trial");

        address[3] memory validators = [validatorA, validatorB, validatorC];
        uint8[3] memory scores =
            [uint8(bound(scoreA, 0, 100)), uint8(bound(scoreB, 0, 100)), uint8(bound(scoreC, 0, 100))];
        bytes32[3] memory salts = [keccak256("a"), keccak256("b"), keccak256("c")];

        vm.warp(proc.trialDeadline + 1);
        for (uint256 i = 0; i < validators.length; ++i) {
            bytes32 commitment = keccak256(abi.encodePacked(pid, agent, validators[i], scores[i], salts[i]));
            vm.prank(validators[i]);
            discovery.commitFinalistScore(pid, agent, commitment, "", new bytes32[](0));
        }

        vm.warp(proc.scoreCommitDeadline + 1);
        for (uint256 i = 0; i < validators.length; ++i) {
            vm.prank(validators[i]);
            discovery.revealFinalistScore(pid, agent, scores[i], salts[i], "", new bytes32[](0));
        }

        vm.warp(proc.scoreRevealDeadline + 1);
        discovery.finalizeWinner(pid);

        uint256 totalBudget = proc.stipendPerFinalist + proc.validatorRewardPerReveal * 3;
        uint256 validatorClaimable =
            discovery.claimable(validatorA) + discovery.claimable(validatorB) + discovery.claimable(validatorC);
        uint256 agentClaimable = discovery.claimable(agent);
        uint256 employerClaimable = discovery.claimable(employer);
        uint256 totalBondPool = proc.validatorScoreBond * 3;

        assertLe(
            validatorClaimable,
            proc.validatorRewardPerReveal * 3 + totalBondPool,
            "validator rewards exceeded reward budget + bonds"
        );
        assertLe(
            agentClaimable,
            proc.finalistStakeTotal + proc.stipendPerFinalist,
            "agent claimable exceeded finalist stake + stipend"
        );
        assertLe(
            validatorClaimable + agentClaimable + employerClaimable,
            totalBudget + proc.finalistStakeTotal + totalBondPool,
            "global discovery distribution overran intended accounting"
        );
    }
}
