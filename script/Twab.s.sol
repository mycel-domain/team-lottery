// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {TwabController} from "pt-v5-twab-controller/TwabController.sol";

// forge script script/Vault.s.sol:DeployVault --rpc-url $OPGOERLI_RPC_UR --broadcast -vvvv --etherscan-api-key $ETHERSCAN_OPTIMISM_API_KEY --verify

contract DeployTwab is Script {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        TwabController twabController = new TwabController(
            3600,
            uint32(block.timestamp)
        );
        console2.log("TwabController deployed at: ", address(twabController));
    }
}
