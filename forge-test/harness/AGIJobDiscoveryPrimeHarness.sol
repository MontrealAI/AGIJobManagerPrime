// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/AGIJobDiscoveryPrime.sol";

contract AGIJobDiscoveryPrimeHarness is AGIJobDiscoveryPrime {
    constructor(address settlementAddress) AGIJobDiscoveryPrime(settlementAddress) {}

    function procurementExists(uint256 procurementId) external view returns (bool) {
        return procurements[procurementId].employer != address(0);
    }

    function procurementView(uint256 procurementId)
        external
        view
        returns (
            address employer,
            uint256 jobId,
            uint64 pauseSecondsBaseline,
            uint64 commitDeadline,
            uint64 revealDeadline,
            uint64 finalistAcceptDeadline,
            uint64 trialDeadline,
            uint64 scoreCommitDeadline,
            uint64 scoreRevealDeadline,
            uint64 selectedAcceptanceWindow,
            uint64 checkpointWindow,
            uint8 finalistCount,
            uint8 minValidatorReveals,
            uint8 maxValidatorRevealsPerFinalist,
            uint256 applicationStake,
            uint256 finalistStakeTotal,
            uint256 stipendPerFinalist,
            uint256 validatorRewardPerReveal,
            uint256 validatorScoreBond,
            bool shortlistFinalized,
            bool winnerFinalized,
            bool cancelled,
            uint256 applicantsLength,
            uint256 finalistsLength
        )
    {
        Procurement storage p = procurements[procurementId];
        return (
            p.employer,
            p.jobId,
            p.pauseSecondsBaseline,
            p.commitDeadline,
            p.revealDeadline,
            p.finalistAcceptDeadline,
            p.trialDeadline,
            p.scoreCommitDeadline,
            p.scoreRevealDeadline,
            p.selectedAcceptanceWindow,
            p.checkpointWindow,
            p.finalistCount,
            p.minValidatorReveals,
            p.maxValidatorRevealsPerFinalist,
            p.applicationStake,
            p.finalistStakeTotal,
            p.stipendPerFinalist,
            p.validatorRewardPerReveal,
            p.validatorScoreBond,
            p.shortlistFinalized,
            p.winnerFinalized,
            p.cancelled,
            p.applicants.length,
            p.finalists.length
        );
    }

    function scoreCommitView(uint256 procurementId, address finalist, address validator)
        external
        view
        returns (bytes32 commitment, bool revealed, uint8 revealedScore, uint256 bond)
    {
        ScoreCommit storage sc = scoreCommits[procurementId][finalist][validator];
        return (sc.commitment, sc.revealed, sc.revealedScore, sc.bond);
    }

    function revealedScoresLength(uint256 procurementId, address finalist) external view returns (uint256) {
        return revealedScores[procurementId][finalist].length;
    }

    function scoreValidatorsList(uint256 procurementId, address finalist) external view returns (address[] memory) {
        return scoreValidators[procurementId][finalist];
    }

    function procurementDeadlines(uint256 procurementId)
        external
        view
        returns (uint64, uint64, uint64, uint64, uint64, uint64)
    {
        Procurement storage p = procurements[procurementId];
        return (
            p.commitDeadline,
            p.revealDeadline,
            p.finalistAcceptDeadline,
            p.trialDeadline,
            p.scoreCommitDeadline,
            p.scoreRevealDeadline
        );
    }

    function procurementActors(uint256 procurementId) external view returns (address employer, uint256 jobId) {
        Procurement storage p = procurements[procurementId];
        return (p.employer, p.jobId);
    }
}
