// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {TwabController} from "pt-v5-twab-controller/TwabController.sol";

contract DeployTwab is Script {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    function _deployTwabController() internal returns (TwabController) {
        return new TwabController(3600, uint32(block.timestamp));
    }

    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        TwabController twabController = _deployTwabController();
        console2.log("TwabController deployed at: ", address(twabController));
        vm.stopBroadcast();
    }
}
