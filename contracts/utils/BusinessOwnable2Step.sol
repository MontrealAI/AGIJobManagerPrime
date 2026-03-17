// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BusinessOwnable2Step is Ownable {
    error InvalidPendingOwner();
    error NotPendingOwner();

    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed pendingOwner);
    event OwnershipTransferCancelled(address indexed owner, address indexed previousPendingOwner);

    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        if (newOwner == address(0)) revert InvalidPendingOwner();

        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    function acceptOwnership() external {
        address candidate = _pendingOwner;
        if (msg.sender != candidate) revert NotPendingOwner();

        _pendingOwner = address(0);
        _transferOwnership(candidate);
    }

    function cancelOwnershipTransfer() external onlyOwner {
        address candidate = _pendingOwner;
        if (candidate == address(0)) revert InvalidPendingOwner();

        _pendingOwner = address(0);
        emit OwnershipTransferCancelled(msg.sender, candidate);
    }
}
