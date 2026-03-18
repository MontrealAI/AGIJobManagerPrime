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

    function jobExists(uint256 jobId) external view returns (bool) {
        return jobs[jobId].employer != address(0);
    }

    function jobView(uint256 jobId)
        external
        view
        returns (
            address employer,
            address assignedAgent,
            address disputeInitiator,
            uint256 payout,
            uint256 duration,
            uint256 disputeBondAmount,
            uint256 validatorBondAmount,
            uint256 agentBondAmount,
            uint256 voteQuorumSnapshot,
            uint256 requiredValidatorApprovalsSnapshot,
            uint256 requiredValidatorDisapprovalsSnapshot,
            uint256 validatorSlashBpsSnapshot,
            uint8 agentPayoutPct,
            uint8 validatorRewardPctSnapshot,
            uint32 validatorApprovals,
            uint32 validatorDisapprovals,
            uint64 completionRequestedAt,
            uint64 disputedAt,
            uint64 validatorApprovedAt,
            uint64 completionReviewPeriodSnapshot,
            uint64 disputeReviewPeriodSnapshot,
            uint64 challengePeriodAfterApprovalSnapshot,
            uint64 pauseSecondsBaseline,
            bool completed,
            bool completionRequested,
            bool disputed,
            bool expired,
            bool escrowReleased,
            bool validatorApproved
        )
    {
        Job storage job = jobs[jobId];
        return (
            job.employer,
            job.assignedAgent,
            job.disputeInitiator,
            job.payout,
            job.duration,
            job.disputeBondAmount,
            job.validatorBondAmount,
            job.agentBondAmount,
            job.voteQuorumSnapshot,
            job.requiredValidatorApprovalsSnapshot,
            job.requiredValidatorDisapprovalsSnapshot,
            job.validatorSlashBpsSnapshot,
            job.agentPayoutPct,
            job.validatorRewardPctSnapshot,
            job.validatorApprovals,
            job.validatorDisapprovals,
            job.completionRequestedAt,
            job.disputedAt,
            job.validatorApprovedAt,
            job.completionReviewPeriodSnapshot,
            job.disputeReviewPeriodSnapshot,
            job.challengePeriodAfterApprovalSnapshot,
            job.pauseSecondsBaseline,
            job.completed,
            job.completionRequested,
            job.disputed,
            job.expired,
            job.escrowReleased,
            job.validatorApproved
        );
    }

    function jobValidatorsLength(uint256 jobId) external view returns (uint256) {
        return jobs[jobId].validators.length;
    }

    function jobVoteState(uint256 jobId, address validator) external view returns (bool approved, bool disapproved) {
        Job storage job = jobs[jobId];
        return (job.approvals[validator], job.disapprovals[validator]);
    }

    function completionNFTAddress() external view returns (address) {
        return address(completionNFT);
    }

    function jobActors(uint256 jobId)
        external
        view
        returns (address employer, address assignedAgent, address disputeInitiator)
    {
        Job storage job = jobs[jobId];
        return (job.employer, job.assignedAgent, job.disputeInitiator);
    }

    function jobTimestamps(uint256 jobId)
        external
        view
        returns (uint64 completionRequestedAt, uint64 disputedAt, uint64 validatorApprovedAt)
    {
        Job storage job = jobs[jobId];
        return (job.completionRequestedAt, job.disputedAt, job.validatorApprovedAt);
    }

    function jobSnapshots(uint256 jobId)
        external
        view
        returns (
            uint64 completionReview,
            uint64 disputeReview,
            uint64 challengeAfterApproval,
            uint256 voteQuorumSnapshot,
            uint256 approvalsSnapshot,
            uint256 disapprovalsSnapshot,
            uint256 slashBpsSnapshot
        )
    {
        Job storage job = jobs[jobId];
        return (
            job.completionReviewPeriodSnapshot,
            job.disputeReviewPeriodSnapshot,
            job.challengePeriodAfterApprovalSnapshot,
            job.voteQuorumSnapshot,
            job.requiredValidatorApprovalsSnapshot,
            job.requiredValidatorDisapprovalsSnapshot,
            job.validatorSlashBpsSnapshot
        );
    }
}
