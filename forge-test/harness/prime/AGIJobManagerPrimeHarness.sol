// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/AGIJobManagerPrime.sol";

contract AGIJobManagerPrimeHarness is AGIJobManagerPrime {
    constructor(
        address agiTokenAddress,
        string memory baseIpfs,
        address ensAddress,
        address nameWrapperAddress,
        bytes32[4] memory rootNodes,
        bytes32[2] memory merkleRoots
    ) AGIJobManagerPrime(agiTokenAddress, baseIpfs, ensAddress, nameWrapperAddress, rootNodes, merkleRoots) {}

    function jobExists(uint256 jobId) external view returns (bool) { return jobs[jobId].employer != address(0); }
    function jobEmployer(uint256 jobId) external view returns (address) { return jobs[jobId].employer; }
    function jobAssignedAgent(uint256 jobId) external view returns (address) { return jobs[jobId].assignedAgent; }
    function jobSelectedAgent(uint256 jobId) external view returns (address) { return jobs[jobId].selectedAgent; }
    function jobPayout(uint256 jobId) external view returns (uint256) { return jobs[jobId].payout; }
    function jobCompleted(uint256 jobId) external view returns (bool) { return jobs[jobId].completed; }
    function jobCompletionRequested(uint256 jobId) external view returns (bool) { return jobs[jobId].completionRequested; }
    function jobDisputed(uint256 jobId) external view returns (bool) { return jobs[jobId].disputed; }
    function jobExpired(uint256 jobId) external view returns (bool) { return jobs[jobId].expired; }
    function jobEscrowReleased(uint256 jobId) external view returns (bool) { return jobs[jobId].escrowReleased; }
    function jobValidatorApproved(uint256 jobId) external view returns (bool) { return jobs[jobId].validatorApproved; }
    function jobValidatorApprovals(uint256 jobId) external view returns (uint32) { return jobs[jobId].validatorApprovals; }
    function jobValidatorDisapprovals(uint256 jobId) external view returns (uint32) { return jobs[jobId].validatorDisapprovals; }
    function jobAssignedAt(uint256 jobId) external view returns (uint64) { return jobs[jobId].assignedAt; }
    function jobCompletionRequestedAt(uint256 jobId) external view returns (uint64) { return jobs[jobId].completionRequestedAt; }
    function jobDisputedAt(uint256 jobId) external view returns (uint64) { return jobs[jobId].disputedAt; }
    function jobValidatorApprovedAt(uint256 jobId) external view returns (uint64) { return jobs[jobId].validatorApprovedAt; }
    function jobSelectionExpiresAt(uint256 jobId) external view returns (uint64) { return jobs[jobId].selectionExpiresAt; }
    function jobCheckpointDeadline(uint256 jobId) external view returns (uint64) { return jobs[jobId].checkpointDeadline; }
    function jobPerJobAgentRoot(uint256 jobId) external view returns (bytes32) { return jobs[jobId].perJobAgentRoot; }
    function jobDisputeBondAmount(uint256 jobId) external view returns (uint256) { return jobs[jobId].disputeBondAmount; }
    function jobValidatorBondAmount(uint256 jobId) external view returns (uint256) { return jobs[jobId].validatorBondAmount; }
    function jobAgentBondAmount(uint256 jobId) external view returns (uint256) { return jobs[jobId].agentBondAmount; }
    function jobValidatorsLength(uint256 jobId) external view returns (uint256) { return jobs[jobId].validators.length; }
    function jobVoteOf(uint256 jobId, address validator) external view returns (bool approved, bool disapproved) {
        Job storage job = jobs[jobId];
        return (job.approvals[validator], job.disapprovals[validator]);
    }
    function completionNFTAddress() external view returns (address) { return address(completionNFT); }
    function completionNFTNextTokenId() external view returns (uint256) { return completionNFT.nextTokenId(); }
    function effectiveTimestampForJob(uint256 jobId) external view returns (uint256) { return _effectiveTimestamp(jobs[jobId]); }
}
