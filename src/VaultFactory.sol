// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Vault} from "./Vault.sol";
import {TwabController} from "pt-v5-twab-controller/TwabController.sol";

contract VaultFactory {
    Vault[] public allVaults;

    event NewFactoryVault(
        Vault indexed vault,
        VaultFactory indexed vaultFactory
    );

    /**
     * @notice Mapping to store deployer nonces for CREATE2
     */
    mapping(address => uint256) public deployerNonces;

    function createVault(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        TwabController twabController_,
        IERC4626 yieldVault_,
        address claimer_,
        address yieldFeeRecipient_,
        uint256 yieldFeePercentage_,
        address owner_
    ) external returns (address) {
        Vault newVault = new Vault{
            salt: keccak256(
                abi.encode(msg.sender, deployerNonces[msg.sender]++)
            )
        }(
            asset_,
            name_,
            symbol_,
            twabController_,
            yieldVault_,
            claimer_,
            yieldFeeRecipient_,
            yieldFeePercentage_,
            owner_
        );
        allVaults.push(newVault);
        emit NewFactoryVault(newVault, VaultFactory(address(this)));
        return address(newVault);
    }

    function totalVaults() external view returns (uint256) {
        return allVaults.length;
    }
}
