// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {VaultV2 as Vault} from "../src/VaultV2.sol";
import {IWETH} from "../test/mock/WETH.sol";

contract DeployVault is Script {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address private _claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address private _yieldFeeRecipient =
        0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address private _owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;

    IERC4626 yieldVault;
    IERC20 UNDERLYING_ASSET_ADDRESS;
    IERC20 AToken;
    TwabController twabController;

    function setUp() public {
        configureChain();
    }

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        Vault vault = new Vault(
            UNDERLYING_ASSET_ADDRESS,
            "Vault waUSDC",
            "vwaUSDC",
            twabController,
            yieldVault,
            _claimer,
            _yieldFeeRecipient,
            0,
            _owner
        );
        console.log("Vault deployed at: ", address(vault));

        vm.stopBroadcast();
    }

    function configureChain() internal {
        if (block.chainid == 80001) {
            // mumbai
            UNDERLYING_ASSET_ADDRESS = IERC20(
                0x52D800ca262522580CeBAD275395ca6e7598C014
            ); // Underlying asset listed in the Aave Protocol

            AToken = IERC20(0x4086fabeE92a080002eeBA1220B9025a27a40A49);
            // yield vault(wrapped aave vault)
            yieldVault = IERC4626(0xB270298208AFAA353f53F52F2011daa241A95e1C);

            // twab controller
            twabController = TwabController(
                0xc83ad197808A948B29c8E94b3345508D296c7F7D
            );
        }
    }
}
