// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {Vault} from "../src/Vault.sol";

contract VaultTest is Test {
    // Underlying WETH
    IERC20 public UNDERLYING_ASSET_ADDRESS =
        IERC20(0x4778caf7b5DBD3934c3906c2909653eB1e0E601f); // Underlying asset listed in the Aave Protocol

    address Claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address Owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    IERC4626 public wrappedAaveVault =
        IERC4626(0x2DD208DB755d75cDaA8e133EDB250Bc50938e6e5);

    uint32 public constant PERIOD_LENGTH = 7 days;
    uint32 public constant PERIOD_OFFSET = 1 days;

    function _deployTwabController() internal returns (TwabController) {
        TwabController twabController = new TwabController(
            PERIOD_LENGTH,
            uint32(block.timestamp)
        );
        console2.log("TwabController deployed at: ", address(twabController));
        return twabController;
    }

    function test_DeployVault() external {
        TwabController twabController = _deployTwabController();

        Vault vault = new Vault(
            UNDERLYING_ASSET_ADDRESS,
            "Vault waWETH",
            "vWETH",
            twabController,
            wrappedAaveVault,
            Claimer,
            Claimer,
            0,
            Owner
        );
        console2.log("Vault deployed at: ", address(vault));
        console2.log("twabController deployed at: ", address(twabController));
    }
}
