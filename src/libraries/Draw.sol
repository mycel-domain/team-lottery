// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniformRandomNumber} from "uniform-random-number/UniformRandomNumber.sol";
import {SD59x18, sd, unwrap, convert} from "prb-math/SD59x18.sol";

library DrawCalculation {
    function isWinner(
        uint256 _teamSpecificRandomNumber,
        uint256 _teamTwab,
        uint256 _vaultTwabTotalSupply,
        SD59x18 _vaultContributionFraction,
        SD59x18 _teamOdds
    ) internal pure returns (bool) {
        if (_vaultTwabTotalSupply == 0) {
            return (false);
        }

        /*
      The user-held portion of the total supply is the "winning zone".
      If the above pseudo-random number falls within the winning zone, the user has won this tier.
      However, we scale the size of the zone based on:
        - Odds of the tier occurring
        - Number of prizes
        - Portion of prize that was contributed by the vault
        */

        return (
            UniformRandomNumber.uniform(_teamSpecificRandomNumber, _vaultTwabTotalSupply)
                < calculateWinningZone(_teamTwab, _vaultContributionFraction, _teamOdds)
        );
    }

    function calculateWinningZone(uint256 _teamTwab, SD59x18 _vaultContributionFraction, SD59x18 _teamOdds)
        internal
        pure
        returns (uint256)
    {
        return uint256(convert(convert(int256(_teamTwab)).mul(_teamOdds).mul(_vaultContributionFraction)));
    }

    function calculatePseudoRandomNumber(
        uint24 _drawId,
        address _vault,
        uint8 _teamId,
        uint256 _totalAmount,
        uint256 _winningRandomNumber
    ) external pure returns (uint256) {
        return uint256(keccak256(abi.encode(_drawId, _vault, _teamId, _totalAmount, _winningRandomNumber)));
    }
}
