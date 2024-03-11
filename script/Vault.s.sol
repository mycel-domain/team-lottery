// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";

import "../src/VaultV2.sol";
import "../src/testnet/ERC20Mintable.sol";
import "../src/testnet/TokenFaucet.sol";
import "../src/testnet/YieldVaultMintRate.sol";

contract DeployVault is Script {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address private _claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address private _yieldFeeRecipient = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address private _owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;

    VaultV2 vault;
    IERC4626 yieldVault;
    IERC20 UNDERLYING_ASSET_ADDRESS;
    IERC20 AToken;
    TwabController twabController = TwabController(0x845a658444e7b344B0c336E54D46F59bd323c65e);
    ERC20Mintable public asset;
    TokenFaucet public faucet;
    YieldVaultMintRate public yieldVaultMintRate;

    function _deploydVault() internal {
        // twabController = new TwabController(3600, uint32(block.timestamp));
        asset = new ERC20Mintable("USDC", "USDC", 6, _owner);
        faucet = new TokenFaucet();
        yieldVaultMintRate = new YieldVaultMintRate(asset, "Spore USDC Yield Vault", "syvUSDC", _owner);

        vault = new VaultV2(
            IERC20(address(asset)),
            "Spore USDC Vault",
            "spvUSDC",
            twabController,
            IERC4626(address(yieldVaultMintRate)),
            _claimer,
            _yieldFeeRecipient,
            0,
            _owner
        );
    }

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        _deploydVault();

        console.log("Vault deployed at: ", address(vault));
        console.log("TwabController deployed at: ", address(twabController));
        console.log("ERC20Mintable deployed at: ", address(asset));
        console.log("TokenFaucet deployed at: ", address(faucet));
        console.log("YieldVaultMintRate deployed at: ", address(yieldVaultMintRate));
        vm.stopBroadcast();
    }
}
