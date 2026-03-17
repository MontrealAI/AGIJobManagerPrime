// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

library ReputationMath {
    function computeHistoricalScore(
        uint256 reputationValue,
        uint64 disputeLosses,
        uint64 expiredJobs,
        uint64 failedJobs
    ) external pure returns (uint256 score) {
        score = reputationValue * 5;
        if (score > 10_000) score = 10_000;

        uint256 penalty = (uint256(disputeLosses) * 600) + (uint256(expiredJobs) * 400) + (uint256(failedJobs) * 100);
        if (penalty > 5_000) penalty = 5_000;

        return score > penalty ? score - penalty : 0;
    }

    function computeReputationPoints(
        uint256 payout,
        uint256 duration,
        uint256 completionRequestedAt,
        uint256 assignedAt,
        bool repEligible
    ) external pure returns (uint256 reputationPoints) {
        if (!repEligible) {
            return 0;
        }
        uint256 completionTime = completionRequestedAt > assignedAt
            ? completionRequestedAt - assignedAt
            : 0;
        unchecked {
            uint256 payoutUnits = payout / 1e15;
            uint256 timeBonus;
            if (duration > completionTime) {
                timeBonus = (duration - completionTime) / 10000;
            }
            uint256 base = Math.log2(1 + payoutUnits);
            if (timeBonus > base) {
                timeBonus = base;
            }
            reputationPoints = base + timeBonus;
        }
    }
}
