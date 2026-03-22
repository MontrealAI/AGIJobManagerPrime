// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IENSJobPagesHooksV1 is IERC165 {
    function onJobCreated(uint256 jobId, address employer, string calldata specURI) external;
    function onJobAssigned(uint256 jobId, address employer, address assignedAgent) external;
    function onJobCompletionRequested(uint256 jobId, string calldata completionURI) external;
    function onJobRevoked(uint256 jobId, address employer, address assignedAgent) external;
    function onJobLocked(uint256 jobId, address employer, address assignedAgent, bool burnFuses) external;

    function jobEnsURI(uint256 jobId) external view returns (string memory);
    function jobEnsIssued(uint256 jobId) external view returns (bool);
}
