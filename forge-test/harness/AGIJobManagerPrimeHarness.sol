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

    function activeJobsByAgentView(address agent) external view returns (uint256) {
        return activeJobsByAgent[agent];
    }

    function jobFlags(uint256 jobId)
        external
        view
        returns (
            bool completed,
            bool completionRequested,
            bool disputed,
            bool expired,
            bool escrowReleased,
            bool validatorApproved
        )
    {
        Job storage job = jobs[jobId];
        return
            (
                job.completed,
                job.completionRequested,
                job.disputed,
                job.expired,
                job.escrowReleased,
                job.validatorApproved
            );
    }

    function jobAccounting(uint256 jobId)
        external
        view
        returns (
            uint256 payout,
            uint256 agentBondAmount,
            uint256 disputeBondAmount,
            uint256 validatorBondAmount,
            uint256 validatorCount,
            address employer,
            address assignedAgent,
            address selectedAgent
        )
    {
        Job storage job = jobs[jobId];
        return (
            job.payout,
            job.agentBondAmount,
            job.disputeBondAmount,
            job.validatorBondAmount,
            job.validators.length,
            job.employer,
            job.assignedAgent,
            job.selectedAgent
        );
    }

    function jobSnapshots(uint256 jobId)
        external
        view
        returns (
            uint64 completionReview,
            uint64 disputeReview,
            uint64 challengePeriod,
            uint256 quorum,
            uint256 approvals,
            uint256 disapprovals,
            uint256 slashBps,
            uint8 payoutPct,
            uint8 validatorRewardPct
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
            job.validatorSlashBpsSnapshot,
            job.agentPayoutPct,
            job.validatorRewardPctSnapshot
        );
    }

    function jobCore(uint256 jobId)
        external
        view
        returns (
            address employer,
            string memory jobSpecURI,
            uint256 payout,
            uint256 duration,
            address assignedAgent,
            bool completed,
            bool expired,
            bool completionRequested,
            bool disputed
        )
    {
        Job storage job = jobs[jobId];
        return (
            job.employer,
            job.jobSpecURI,
            job.payout,
            job.duration,
            job.assignedAgent,
            job.completed,
            job.expired,
            job.completionRequested,
            job.disputed
        );
    }

    function jobTiming(uint256 jobId)
        external
        view
        returns (
            uint64 selectionExpiresAt,
            uint64 checkpointDeadline,
            uint64 assignedAt,
            uint64 completionRequestedAt,
            uint64 disputedAt,
            uint64 validatorApprovedAt,
            uint64 pauseSecondsBaseline,
            uint256 effectiveNow
        )
    {
        Job storage job = jobs[jobId];
        return (
            job.selectionExpiresAt,
            job.checkpointDeadline,
            job.assignedAt,
            job.completionRequestedAt,
            job.disputedAt,
            job.validatorApprovedAt,
            job.pauseSecondsBaseline,
            _effectiveTimestamp(job)
        );
    }

    function jobValidatorParticipation(uint256 jobId)
        external
        view
        returns (uint256 approvals, uint256 disapprovals, uint256 validatorsLength)
    {
        Job storage job = jobs[jobId];
        return (job.validatorApprovals, job.validatorDisapprovals, job.validators.length);
    }
}
