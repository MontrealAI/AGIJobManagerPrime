// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IENSJobPagesHooksV1.sol";

interface IENSJobPages is IENSJobPagesHooksV1 {
    function lockConfiguration() external;
    function configLocked() external view returns (bool);
    function jobEnsName(uint256 jobId) external view returns (string memory);
    function setUseEnsJobTokenURI(bool enabled) external;
}
