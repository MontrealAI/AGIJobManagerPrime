// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "contracts/utils/BondMath.sol";
import "contracts/utils/ReputationMath.sol";
import "contracts/utils/UriUtils.sol";
import "contracts/utils/BusinessOwnable2Step.sol";
import "contracts/periphery/AGIJobCompletionNFT.sol";

contract Ownable2StepHarness is BusinessOwnable2Step {
    constructor() Ownable() {}

    function renounceOwnership() public view override onlyOwner {
        revert("disabled");
    }
}

contract PrimeMathAndBoundaryFuzz is Test {
    function testFuzz_validatorBondAlwaysBounded(uint256 payout, uint256 bps, uint256 minBond, uint256 maxBond)
        external
    {
        payout = bound(payout, 1, type(uint128).max);
        bps = bound(bps, 0, 10_000);
        maxBond = bound(maxBond, minBond, payout + minBond + 1);
        uint256 bond = BondMath.computeValidatorBond(payout, bps, minBond, maxBond);
        assertLe(bond, payout);
        if (bps == 0 && minBond == 0 && maxBond == 0) assertEq(bond, 0);
        if (maxBond != 0) assertLe(bond, maxBond);
    }

    function testFuzz_agentBondAlwaysBounded(
        uint256 payout,
        uint256 duration,
        uint256 bps,
        uint256 minBond,
        uint256 maxBond,
        uint256 durationLimit
    ) external {
        payout = bound(payout, 1, type(uint128).max);
        duration = bound(duration, 0, 365 days);
        bps = bound(bps, 0, 10_000);
        maxBond = bound(maxBond, minBond, payout + minBond + 1);
        durationLimit = bound(durationLimit, 0, 365 days);
        uint256 bond = BondMath.computeAgentBond(payout, duration, bps, minBond, maxBond, durationLimit);
        assertLe(bond, payout);
        if (maxBond != 0) assertLe(bond, maxBond);
    }

    function testFuzz_reputationMathZeroWhenIneligible(
        uint256 payout,
        uint256 duration,
        uint256 completionRequestedAt,
        uint256 assignedAt
    ) external pure {
        assertEq(ReputationMath.computeReputationPoints(payout, duration, completionRequestedAt, assignedAt, false), 0);
    }

    function testFuzz_applyBaseIpfsKeepsAbsoluteUris(string memory uri, string memory base) external pure {
        vm.assume(bytes(uri).length > 0);
        vm.assume(bytes(base).length > 0);
        string memory absolute = string.concat("https://", uri);
        assertEq(UriUtils.applyBaseIpfs(absolute, base), absolute);
    }

    function testFuzz_twoStepOwnershipRequiresPendingOwner(address newOwner, address outsider) external {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner != outsider);
        Ownable2StepHarness h = new Ownable2StepHarness();
        h.transferOwnership(newOwner);
        vm.prank(outsider);
        vm.expectRevert(BusinessOwnable2Step.NotPendingOwner.selector);
        h.acceptOwnership();
        vm.prank(newOwner);
        h.acceptOwnership();
        assertEq(h.owner(), newOwner);
    }

    function test_completionNftOnlyManagerCanMint(address caller, address recipient, string calldata uri) external {
        AGIJobCompletionNFT nft = new AGIJobCompletionNFT(address(this));
        if (caller != address(this)) {
            vm.prank(caller);
            vm.expectRevert(AGIJobCompletionNFT.NotManager.selector);
            nft.mintCompletion(recipient, uri);
        } else {
            nft.mintCompletion(recipient, uri);
            assertEq(nft.ownerOf(0), recipient);
        }
    }
}
