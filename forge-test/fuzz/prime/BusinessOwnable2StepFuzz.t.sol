// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "contracts/AGIJobDiscoveryPrime.sol";
import "forge-test/harness/prime/AGIJobManagerPrimeHarness.sol";
import "contracts/test/MockERC20.sol";

contract BusinessOwnable2StepFuzz is Test {
    MockERC20 internal token;
    AGIJobManagerPrimeHarness internal manager;
    AGIJobDiscoveryPrime internal discovery;

    function setUp() external {
        token = new MockERC20();
        bytes32[4] memory rootNodes;
        bytes32[2] memory merkleRoots;
        manager = new AGIJobManagerPrimeHarness(address(token), "", address(0), address(0), rootNodes, merkleRoots);
        discovery = new AGIJobDiscoveryPrime(address(manager));
    }

    function testFuzz_transferAcceptCancel(address nextOwner, address randomCaller) external {
        vm.assume(nextOwner != address(0));
        vm.assume(nextOwner != discovery.owner());
        vm.prank(discovery.owner());
        discovery.transferOwnership(nextOwner);
        assertEq(discovery.pendingOwner(), nextOwner);

        vm.prank(randomCaller);
        vm.expectRevert();
        discovery.acceptOwnership();

        vm.prank(discovery.owner());
        discovery.cancelOwnershipTransfer();
        assertEq(discovery.pendingOwner(), address(0));

        vm.prank(discovery.owner());
        discovery.transferOwnership(nextOwner);
        vm.prank(nextOwner);
        discovery.acceptOwnership();
        assertEq(discovery.owner(), nextOwner);
        assertEq(discovery.pendingOwner(), address(0));
    }

    function test_renounceOwnershipDisabled() external {
        vm.prank(discovery.owner());
        vm.expectRevert();
        discovery.renounceOwnership();
    }
}
