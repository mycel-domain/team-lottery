// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {VaultV2 as Vault} from "../src/VaultV2.sol";

// forge script script/Vault.s.sol:DeployVault --rpc-url $OPGOERLI_RPC_UR --broadcast -vvvv --etherscan-api-key $ETHERSCAN_OPTIMISM_API_KEY --verify

contract DeployVault is Script {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    // Underlying WETH
    IERC20 public UNDERLYING_ASSET_ADDRESS =
        IERC20(0x4778caf7b5DBD3934c3906c2909653eB1e0E601f); // Underlying asset listed in the Aave Protocol

    address Claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address Owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    IERC4626 public wrappedAaveVault =
        IERC4626(0x2DD208DB755d75cDaA8e133EDB250Bc50938e6e5);

    uint32 public constant PERIOD_LENGTH = 1 days;
    uint32 public constant PERIOD_OFFSET = 1708082387;

    function _deployTwabController() internal returns (TwabController) {
        TwabController twabController = new TwabController(
            PERIOD_LENGTH,
            PERIOD_OFFSET
        );
        console2.log("TwabController deployed at: ", address(twabController));
        return twabController;
    }

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
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
        vm.stopBroadcast();
    }
}
