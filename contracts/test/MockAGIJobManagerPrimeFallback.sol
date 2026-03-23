// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IENSJobPagesHandleOnlyV2 {
    function handleHook(uint8 hook, uint256 jobId) external;
}

contract MockAGIJobManagerPrimeFallback {
    mapping(uint256 => address) private _employer;
    mapping(uint256 => address) private _agent;

    function setJob(uint256 jobId, address employer, address agent) external {
        _employer[jobId] = employer;
        _agent[jobId] = agent;
    }

    function jobEmployerOf(uint256 jobId) external view returns (address) {
        return _employer[jobId];
    }

    function jobAssignedAgentOf(uint256 jobId) external view returns (address) {
        return _agent[jobId];
    }

    function callHandleHook(address pages, uint8 hook, uint256 jobId) external {
        IENSJobPagesHandleOnlyV2(pages).handleHook(hook, jobId);
    }
}
