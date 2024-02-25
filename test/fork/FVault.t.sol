// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";

import {VaultV2} from "../../src/VaultV2.sol";
import {IWETH} from "../mock/WETH.sol";

contract FVaultTest is Test {
    address _claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _yieldFeeRecipient = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;

    IWETH weth;
    // Optimism weth vault

    IERC4626 _yieldVault;
    IERC20 UNDERLYING_ASSET_ADDRESS;
    TwabController _twabController;

    function setUp() public {
        // weth address
        UNDERLYING_ASSET_ADDRESS = IERC20(
            0x4200000000000000000000000000000000000006
        ); // Underlying asset listed in the Aave Protocol
        weth = IWETH(0x4200000000000000000000000000000000000006);
        // yield vault(wrapped aave vault)
        _yieldVault = IERC4626(0xB0f04cFB784313F97588F3D3be1b26C231122232);

        // twab controller
        _twabController = TwabController(
            0x499a9F249ec4c8Ea190bebbFD96f9A83bf4F6E52
        );
    }

    function test_deployVault() public {
        VaultV2 vault = __deployVaultV2();
        console2.log("Vault deployed at: ", address(vault));
    }

    function test_weth() public {
        UNDERLYING_ASSET_ADDRESS.balanceOf(_owner);
        vm.deal(_owner, 1 ether);
        vm.startPrank(_owner);

        weth.deposit{value: 0.1 ether}();
        weth.approve(address(this), 0.1 ether);
        assertEq(UNDERLYING_ASSET_ADDRESS.balanceOf(_owner), 0.1 ether);
        assertEq(weth.allowance(_owner, address(this)), 0.1 ether);
    }

    function test_deposit() public {
        VaultV2 vault = __deployVaultV2();
        vm.deal(_owner, 1 ether);
        vm.deal(address(this), 1 ether);
        vm.startPrank(_owner);
        weth.deposit{value: 0.1 ether}();
        weth.approve(address(vault), 0.1 ether);
        vault.deposit(0.1 ether, _owner);
        console2.log(
            "owner's balanceOf vault share: ",
            vault.balanceOf(_owner)
        );
        console2.log("totalAssets", vault.totalAssets());
        console2.log("totalSupply", vault.totalSupply());
        console2.log("owner's balanceOf weth: ", weth.balanceOf(_owner));
        console2.log(
            "vault's balanceOf weth: ",
            weth.balanceOf(address(vault))
        );
        console.log(
            "vault's share of yield",
            _yieldVault.balanceOf(address(vault))
        );
    }

    function __deployVaultV2() internal returns (VaultV2) {
        return
            new VaultV2(
                UNDERLYING_ASSET_ADDRESS,
                "Vault waWETH",
                "vWETH",
                _twabController,
                _yieldVault,
                _claimer,
                _yieldFeeRecipient,
                0,
                _owner
            );
    }
}
