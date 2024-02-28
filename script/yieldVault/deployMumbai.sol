// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {CREATE3Factory} from "create3-factory/src/CREATE3Factory.sol";
import {AaveV3ERC4626Factory} from "yield-daddy/aave-v3/AaveV3ERC4626Factory.sol";

contract DeployScript is Script {
    function run() public returns (AaveV3ERC4626Factory deployed) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        CREATE3Factory create3 = CREATE3Factory(
            0x4dE723974c4f95aE0c7fF26f334D3edccAa83A68
        );
        address rewardsController = vm.envAddress(
            "AAVE_V3_REWARDS_CONTROLLER_POLYGON"
        );
        address rewardRecipient = vm.envAddress(
            "AAVE_V3_REWARDS_RECIPIENT_POLYGON"
        );
        address lendingPool = vm.envAddress("AAVE_V3_LENDING_POOL_POLYGON");

        vm.startBroadcast(deployerPrivateKey);

        deployed = AaveV3ERC4626Factory(
            create3.deploy(
                keccak256("AaveV3ERC4626Factory"),
                bytes.concat(
                    type(AaveV3ERC4626Factory).creationCode,
                    abi.encode(lendingPool, rewardRecipient, rewardsController)
                )
            )
        );

        vm.stopBroadcast();
    }
}
