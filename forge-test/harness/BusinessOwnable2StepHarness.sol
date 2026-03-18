// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/utils/BusinessOwnable2Step.sol";

contract BusinessOwnable2StepHarness is BusinessOwnable2Step {
    function renounceOwnership() public view override onlyOwner {
        revert("RENOUNCE_DISABLED");
    }
}
