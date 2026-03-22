// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IAGIJobManagerENSViewV1 is IERC165 {
    function getJobCore(uint256 jobId)
        external
        view
        returns (
            address employer,
            address assignedAgent,
            uint256 payout,
            uint256 duration,
            uint256 assignedAt,
            bool completed,
            bool disputed,
            bool expired,
            uint8 agentPayoutPct
        );

    function getJobSpecURI(uint256 jobId) external view returns (string memory);
    function getJobCompletionURI(uint256 jobId) external view returns (string memory);
}
