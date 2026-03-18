// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "contracts/test/UtilsHarness.sol";
import "contracts/test/MockENS.sol";
import "contracts/test/MockResolver.sol";
import "contracts/test/MockNameWrapper.sol";

contract PrimeUtilityFuzz is Test {
    UtilsHarness internal utils;

    function setUp() external {
        utils = new UtilsHarness();
    }

    function testFuzz_applyBaseIpfs_doesNotDoublePrefix(string memory path, bool trailingSlash) external view {
        vm.assume(bytes(path).length > 0);
        vm.assume(bytes(path).length < 96);
        vm.assume(bytes(path)[0] != 0x20);
        string memory base = trailingSlash ? "ipfs://root/" : "ipfs://root";
        string memory full = utils.applyBaseIpfs(path, base);
        assertTrue(bytes(full).length >= bytes(path).length);
        if (bytes(path).length >= 7) {
            bytes memory data = bytes(path);
            bool hasScheme;
            for (uint256 i = 0; i + 2 < data.length; ++i) {
                if (data[i] == ":" && data[i + 1] == "/" && data[i + 2] == "/") {
                    hasScheme = true;
                    break;
                }
            }
            if (hasScheme) {
                assertEq(full, path);
            }
        }
    }

    function testFuzz_bondMath_respectsCaps(uint256 payout, uint256 bps, uint256 minBond, uint256 maxBond) external view {
        payout = bound(payout, 0, 10_000 ether);
        bps = bound(bps, 0, 20_000);
        minBond = bound(minBond, 0, 10_000 ether);
        maxBond = bound(maxBond, minBond, 10_000 ether);
        uint256 validatorBond = utils.computeValidatorBond(payout, bps, minBond, maxBond);
        assertLe(validatorBond, payout);
        if (!(bps == 0 && minBond == 0 && maxBond == 0)) {
            assertLe(validatorBond, maxBond);
        }
        uint256 agentBond = utils.computeAgentBond(payout, 30 days, bps, minBond, maxBond, 365 days);
        assertLe(agentBond, payout);
        if (maxBond != 0) assertLe(agentBond, maxBond);
    }

    function testFuzz_reputationMath_monotonicWithEligibility(
        uint256 payout,
        uint256 duration,
        uint64 completionRequestedAt,
        uint64 assignedAt
    ) external view {
        payout = bound(payout, 0, 1_000_000 ether);
        duration = bound(duration, 1, 365 days);
        uint256 ineligible = utils.computeReputationPoints(payout, duration, completionRequestedAt, assignedAt, false);
        uint256 eligible = utils.computeReputationPoints(payout, duration, completionRequestedAt, assignedAt, true);
        assertEq(ineligible, 0);
        assertGe(eligible, ineligible);
    }

    function testFuzz_ensOwnership_acceptsWrapperOrResolverPaths(bytes32 /*labelSalt*/, address claimant) external {
        vm.assume(claimant != address(0));
        MockNameWrapper wrapper = new MockNameWrapper();
        MockENS ens = new MockENS();
        MockResolver resolver = new MockResolver();
        bytes32 rootNode = keccak256("root");
        string memory label = "agent";
        bytes32 subnode = keccak256(abi.encodePacked(rootNode, keccak256(bytes(label))));

        wrapper.setOwner(uint256(subnode), claimant);
        assertTrue(utils.verifyENSOwnership(address(ens), address(wrapper), claimant, label, rootNode));

        wrapper.setOwner(uint256(subnode), address(0xB0B));
        ens.setResolver(subnode, address(resolver));
        resolver.setAddr(subnode, claimant);
        assertTrue(utils.verifyENSOwnership(address(ens), address(wrapper), claimant, label, rootNode));
    }
}
