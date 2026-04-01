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
            bool shortlistFinalized,
            bool winnerFinalized,
            bool cancelled,
            uint64 pauseSecondsBaseline,
            uint64 commitDeadline,
            uint64 revealDeadline,
            uint64 finalistAcceptDeadline,
            uint64 trialDeadline,
            uint64 scoreCommitDeadline,
            uint64 scoreRevealDeadline,
            uint8 finalistCount,
            uint8 minValidatorReveals,
            uint8 maxValidatorRevealsPerFinalist,
            uint256 applicationStake,
            uint256 finalistStakeTotal,
            uint256 stipendPerFinalist,
            uint256 validatorRewardPerReveal,
            uint256 validatorScoreBond,
            uint256 effectiveNow
        )
    {
        Procurement storage p = procurements[procurementId];
        return (
            p.employer,
            p.jobId,
            p.shortlistFinalized,
            p.winnerFinalized,
            p.cancelled,
            p.pauseSecondsBaseline,
            p.commitDeadline,
            p.revealDeadline,
            p.finalistAcceptDeadline,
            p.trialDeadline,
            p.scoreCommitDeadline,
            p.scoreRevealDeadline,
            p.finalistCount,
            p.minValidatorReveals,
            p.maxValidatorRevealsPerFinalist,
            p.applicationStake,
            p.finalistStakeTotal,
            p.stipendPerFinalist,
            p.validatorRewardPerReveal,
            p.validatorScoreBond,
            _effectiveTimestamp(p)
        );
    }

    function applicationSettled(uint256 procurementId, address agent) external view returns (bool) {
        return applications[procurementId][agent].settled;
    }

    function applicationCommitment(uint256 procurementId, address agent) external view returns (bytes32) {
        return applications[procurementId][agent].commitment;
    }

    function scoreCommitView(uint256 procurementId, address finalist, address validator)
        external
        view
        returns (bytes32 commitment, bool revealed, uint8 revealedScore, uint256 bond)
    {
        ScoreCommit storage sc = scoreCommits[procurementId][finalist][validator];
        return (sc.commitment, sc.revealed, sc.revealedScore, sc.bond);
    }

    function revealedScoreCount(uint256 procurementId, address finalist) external view returns (uint256) {
        return revealedScores[procurementId][finalist].length;
    }

    function pausedSecondsNowView() external view returns (uint64) {
        return _pausedSecondsNow();
    }

    function effectiveTimestampView(uint256 procurementId) external view returns (uint256) {
        return _effectiveTimestamp(procurements[procurementId]);
    }

    function procurementPauseBaselineView(uint256 procurementId) external view returns (uint64) {
        return procurements[procurementId].pauseSecondsBaseline;
    }
}
