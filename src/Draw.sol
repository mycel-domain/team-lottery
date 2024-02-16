// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract Draw {
    address public manager;
    address[] public players;

    function calculatePseudoRandomNumber(
        uint24 _drawId,
        address _vault,
        address _user,
        uint8 _tier,
        uint32 _prizeIndex,
        uint256 _winningRandomNumber
    ) external pure returns (uint256) {
        return
            _calculatePseudoRandomNumber(
                _drawId,
                _vault,
                _user,
                _tier,
                _prizeIndex,
                _winningRandomNumber
            );
    }

    /// @notice Calculates a pseudo-random number that is unique to the user, tier, and winning random number.
    /// @param _drawId The draw id the user is checking
    /// @param _vault The vault the user deposited into
    /// @param _user The user
    /// @param _tier The tier
    /// @param _prizeIndex The particular prize index they are checking
    /// @param _winningRandomNumber The winning random number
    /// @return A pseudo-random number
    function _calculatePseudoRandomNumber(
        uint24 _drawId,
        address _vault,
        address _user,
        uint8 _tier,
        uint32 _prizeIndex,
        uint256 _winningRandomNumber
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        _drawId,
                        _vault,
                        _user,
                        _tier,
                        _prizeIndex,
                        _winningRandomNumber
                    )
                )
            );
    }
}
