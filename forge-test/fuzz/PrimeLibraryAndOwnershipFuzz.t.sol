// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "contracts/test/UtilsHarness.sol";
import "forge-test/harness/BusinessOwnable2StepHarness.sol";

contract PrimeLibraryAndOwnershipFuzz is Test {
    UtilsHarness internal harness;
    BusinessOwnable2StepHarness internal ownable;

    address internal owner = address(0xA11CE);
    address internal pending = address(0xB0B);
    address internal outsider = address(0xCAFE);

    function setUp() external {
        vm.prank(owner);
        ownable = new BusinessOwnable2StepHarness();
        harness = new UtilsHarness();
    }

    function testFuzz_validatorBondBoundedAndMonotonic(
        uint96 payoutSeed,
        uint16 bpsA,
        uint16 bpsB,
        uint96 minSeed,
        uint96 maxSeed
    ) external view {
        uint256 payout = bound(uint256(payoutSeed), 1, type(uint96).max);
        uint256 minBond = bound(uint256(minSeed), 0, payout);
        uint256 maxBond = bound(uint256(maxSeed), minBond, payout);
        uint256 lowBps = bound(uint256(bpsA), 0, 10_000);
        uint256 highBps = bound(uint256(bpsB), lowBps, 10_000);

        uint256 low = harness.computeValidatorBond(payout, lowBps, minBond, maxBond);
        uint256 high = harness.computeValidatorBond(payout, highBps, minBond, maxBond);

        assertLe(low, payout);
        assertLe(high, payout);
        assertLe(low, maxBond);
        assertLe(high, maxBond);
        if (lowBps > 0 || minBond > 0 || maxBond > 0) {
            assertGe(low, minBond);
            assertGe(high, minBond);
        }
        assertGe(high, low);
    }

    function testFuzz_agentBondBounded(
        uint96 payoutSeed,
        uint64 durationSeed,
        uint16 bps,
        uint96 minSeed,
        uint96 maxSeed,
        uint64 limitSeed
    ) external view {
        uint256 payout = bound(uint256(payoutSeed), 1, 1e30);
        uint256 duration = bound(uint256(durationSeed), 0, 365 days);
        uint256 minBond = bound(uint256(minSeed), 0, payout);
        uint256 maxBond = bound(uint256(maxSeed), minBond, payout);
        uint256 durationLimit = bound(uint256(limitSeed), 1, 365 days);
        uint256 bond =
            harness.computeAgentBond(payout, duration, bound(uint256(bps), 0, 10_000), minBond, maxBond, durationLimit);
        assertLe(bond, payout);
        if (maxBond > 0) assertLe(bond, maxBond);
        if (bps > 0 || minBond > 0 || maxBond > 0) assertGe(bond, minBond);
    }

    function testFuzz_reputationZeroWhenIneligible(
        uint96 payout,
        uint64 duration,
        uint64 requestedAt,
        uint64 assignedAt
    ) external view {
        uint256 points = harness.computeReputationPoints(payout, duration, requestedAt, assignedAt, false);
        assertEq(points, 0);
    }

    function testFuzz_applyBaseIpfsNeverDuplicatesSlash(string memory tail) external view {
        vm.assume(bytes(tail).length > 0);
        string memory joined = harness.applyBaseIpfs(tail, "ipfs://base/");
        assertTrue(bytes(joined).length >= bytes(tail).length);
        assertEq(harness.applyBaseIpfs("https://already", "ipfs://base/"), "https://already");
    }

    function testFuzz_requireValidUriRejectsWhitespace(bytes memory raw) external {
        vm.assume(raw.length > 0 && raw.length < 64);
        bool hasWhitespace;
        for (uint256 i = 0; i < raw.length; ++i) {
            bytes1 c = raw[i];
            if (c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d) {
                hasWhitespace = true;
                break;
            }
        }
        if (hasWhitespace) {
            vm.expectRevert();
            harness.requireValidUri(string(raw));
        } else {
            harness.requireValidUri(string(raw));
        }
    }

    function testFuzz_twoStepOwnershipOnlyPendingOwnerCanAccept(address newOwner, address wrongCaller) external {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != owner);
        vm.assume(wrongCaller != newOwner);

        vm.prank(owner);
        ownable.transferOwnership(newOwner);
        assertEq(ownable.pendingOwner(), newOwner);

        vm.prank(wrongCaller);
        vm.expectRevert(BusinessOwnable2Step.NotPendingOwner.selector);
        ownable.acceptOwnership();

        vm.prank(newOwner);
        ownable.acceptOwnership();
        assertEq(ownable.owner(), newOwner);
        assertEq(ownable.pendingOwner(), address(0));
    }

    function test_cancelOwnershipTransferClearsPendingOwner() external {
        vm.prank(owner);
        ownable.transferOwnership(pending);
        vm.prank(owner);
        ownable.cancelOwnershipTransfer();
        assertEq(ownable.pendingOwner(), address(0));
    }
}
