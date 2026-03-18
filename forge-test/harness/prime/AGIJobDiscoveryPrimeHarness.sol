// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/AGIJobDiscoveryPrime.sol";

contract AGIJobDiscoveryPrimeHarness is AGIJobDiscoveryPrime {
    constructor(address settlementAddress) AGIJobDiscoveryPrime(settlementAddress) {}

    function procurementEmployer(uint256 procurementId) external view returns (address) { return procurements[procurementId].employer; }
    function procurementJobIdView(uint256 procurementId) external view returns (uint256) { return procurements[procurementId].jobId; }
    function procurementFinalistAcceptDeadline(uint256 procurementId) external view returns (uint64) { return procurements[procurementId].finalistAcceptDeadline; }
    function procurementTrialDeadline(uint256 procurementId) external view returns (uint64) { return procurements[procurementId].trialDeadline; }
    function procurementScoreCommitDeadline(uint256 procurementId) external view returns (uint64) { return procurements[procurementId].scoreCommitDeadline; }
    function procurementScoreRevealDeadline(uint256 procurementId) external view returns (uint64) { return procurements[procurementId].scoreRevealDeadline; }
    function procurementFinalistCount(uint256 procurementId) external view returns (uint8) { return procurements[procurementId].finalistCount; }
    function procurementMinValidatorReveals(uint256 procurementId) external view returns (uint8) { return procurements[procurementId].minValidatorReveals; }
    function procurementMaxValidatorReveals(uint256 procurementId) external view returns (uint8) { return procurements[procurementId].maxValidatorRevealsPerFinalist; }
    function procurementApplicationStake(uint256 procurementId) external view returns (uint256) { return procurements[procurementId].applicationStake; }
    function procurementStipendPerFinalist(uint256 procurementId) external view returns (uint256) { return procurements[procurementId].stipendPerFinalist; }
    function procurementValidatorRewardPerReveal(uint256 procurementId) external view returns (uint256) { return procurements[procurementId].validatorRewardPerReveal; }
    function procurementValidatorScoreBond(uint256 procurementId) external view returns (uint256) { return procurements[procurementId].validatorScoreBond; }
    function procurementShortlistFinalized(uint256 procurementId) external view returns (bool) { return procurements[procurementId].shortlistFinalized; }
    function procurementWinnerFinalized(uint256 procurementId) external view returns (bool) { return procurements[procurementId].winnerFinalized; }
    function procurementCancelled(uint256 procurementId) external view returns (bool) { return procurements[procurementId].cancelled; }
    function procurementApplicantsLength(uint256 procurementId) external view returns (uint256) { return procurements[procurementId].applicants.length; }
    function procurementFinalistsLength(uint256 procurementId) external view returns (uint256) { return procurements[procurementId].finalists.length; }
    function effectiveTimestampForProcurement(uint256 procurementId) external view returns (uint256) { return _effectiveTimestamp(procurements[procurementId]); }
    function revealedScoresLength(uint256 procurementId, address finalist) external view returns (uint256) { return revealedScores[procurementId][finalist].length; }
    function scoreCommitView(uint256 procurementId, address finalist, address validator) external view returns (bytes32 commitment, bool revealed, uint8 revealedScore, uint256 bond) {
        ScoreCommit storage sc = scoreCommits[procurementId][finalist][validator];
        return (sc.commitment, sc.revealed, sc.revealedScore, sc.bond);
    }
    function scoreValidatorsLength(uint256 procurementId, address finalist) external view returns (uint256) { return scoreValidators[procurementId][finalist].length; }
    function applicationLockedStake(uint256 procurementId, address agent) external view returns (uint256) { return applications[procurementId][agent].lockedStake; }
    function applicationRevealed(uint256 procurementId, address agent) external view returns (bool) { return applications[procurementId][agent].revealed; }
    function applicationShortlisted(uint256 procurementId, address agent) external view returns (bool) { return applications[procurementId][agent].shortlisted; }
    function applicationFinalistAccepted(uint256 procurementId, address agent) external view returns (bool) { return applications[procurementId][agent].finalistAccepted; }
    function applicationTrialSubmitted(uint256 procurementId, address agent) external view returns (bool) { return applications[procurementId][agent].trialSubmitted; }
    function applicationEverPromoted(uint256 procurementId, address agent) external view returns (bool) { return applications[procurementId][agent].everPromoted; }
}
