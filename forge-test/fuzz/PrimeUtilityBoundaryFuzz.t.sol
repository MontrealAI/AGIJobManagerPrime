// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "contracts/utils/BondMath.sol";
import "contracts/utils/ReputationMath.sol";
import "contracts/utils/UriUtils.sol";
import "contracts/utils/BusinessOwnable2Step.sol";

contract BusinessOwnable2StepHarness is BusinessOwnable2Step {
    function renounceOwnership() public view override onlyOwner {
        revert("RENOUNCE_DISABLED");
    }
}

contract PrimeUtilityBoundaryFuzz is Test {
    function testFuzz_agentBondBoundariesStayClamped(
        uint256 payout,
        uint256 duration,
        uint256 bps,
        uint256 minBond,
        uint256 maxBond,
        uint256 durationLimit
    ) external pure {
        payout = bound(payout, 0, 1_000_000 ether);
        duration = bound(duration, 0, 365 days);
        bps = bound(bps, 0, 20_000);
        minBond = bound(minBond, 0, 100_000 ether);
        maxBond = bound(maxBond, 0, 100_000 ether);
        durationLimit = bound(durationLimit, 0, 365 days);

        uint256 bond = BondMath.computeAgentBond(payout, duration, bps, minBond, maxBond, durationLimit);
        assertLe(bond, payout, "agent bond exceeded payout");
        if (bps == 0 && minBond == 0 && maxBond == 0) {
            assertEq(bond, 0, "zero-config bond should stay zero");
        }
        if (maxBond != 0) {
            assertLe(bond, maxBond, "agent bond exceeded maxBond");
        }
    }

    function testFuzz_validatorBondBoundariesStayClamped(uint256 payout, uint256 bps, uint256 minBond, uint256 maxBond)
        external
        pure
    {
        payout = bound(payout, 0, 1_000_000 ether);
        bps = bound(bps, 0, 20_000);
        minBond = bound(minBond, 0, 100_000 ether);
        maxBond = bound(maxBond, 0, 100_000 ether);

        uint256 bond = BondMath.computeValidatorBond(payout, bps, minBond, maxBond);
        assertLe(bond, payout, "validator bond exceeded payout");
        if (bps == 0 && minBond == 0 && maxBond == 0) {
            assertEq(bond, 0, "zero-config validator bond should stay zero");
        }
    }

    function testFuzz_reputationPointsStayMonotonicOnPayout(
        uint256 payoutA,
        uint256 payoutB,
        uint256 duration,
        uint256 completionRequestedAt,
        uint256 assignedAt
    ) external pure {
        payoutA = bound(payoutA, 0, 1_000_000 ether);
        payoutB = bound(payoutB, payoutA, 1_000_000 ether);
        duration = bound(duration, 0, 365 days);
        assignedAt = bound(assignedAt, 0, 365 days);
        completionRequestedAt = bound(completionRequestedAt, assignedAt, assignedAt + 365 days);

        uint256 pointsA =
            ReputationMath.computeReputationPoints(payoutA, duration, completionRequestedAt, assignedAt, true);
        uint256 pointsB =
            ReputationMath.computeReputationPoints(payoutB, duration, completionRequestedAt, assignedAt, true);
        assertLe(pointsA, pointsB, "reputation points regressed on larger payout");
    }

    function testFuzz_uriValidationRejectsWhitespace(bytes calldata raw) external {
        string memory uri = string(raw);
        bool hasWhitespace;
        bytes memory data = bytes(uri);
        for (uint256 i = 0; i < data.length; ++i) {
            bytes1 c = data[i];
            if (c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d) {
                hasWhitespace = true;
                break;
            }
        }

        if (data.length == 0 || hasWhitespace) {
            vm.expectRevert();
            UriUtils.requireValidUri(uri);
        } else {
            UriUtils.requireValidUri(uri);
        }
    }

    function testFuzz_applyBaseIpfsPreservesSchemedUris(string calldata uri, string calldata base) external pure {
        bytes memory b = bytes(uri);
        bool hasScheme;
        for (uint256 i = 0; i + 2 < b.length; ++i) {
            if (b[i] == 0x3a && b[i + 1] == 0x2f && b[i + 2] == 0x2f) {
                hasScheme = true;
                break;
            }
        }

        string memory out = UriUtils.applyBaseIpfs(uri, base);
        if (hasScheme || bytes(base).length == 0) {
            assertEq(out, uri, "schemed URI/base-empty path must remain unchanged");
        }
    }

    function test_businessOwnable2StepTransferFlow(address pending) external {
        vm.assume(pending != address(0));
        BusinessOwnable2StepHarness ownable = new BusinessOwnable2StepHarness();
        ownable.transferOwnership(pending);
        assertEq(ownable.pendingOwner(), pending);

        vm.prank(pending);
        ownable.acceptOwnership();
        assertEq(ownable.owner(), pending);
        assertEq(ownable.pendingOwner(), address(0));
    }
}
