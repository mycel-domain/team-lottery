// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {SD59x18, sd, unwrap, convert} from "prb-math/SD59x18.sol";
import {VaultV2} from "../../src/VaultV2.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IFaucet} from "../interfaces/IFaucet.sol";

contract FVaultTest is Test {
    address _claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _yieldFeeRecipient = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;

    IWETH public weth;
    IERC4626 public yieldVault;
    IERC20 public AToken;
    TwabController public twabController;

    function setUp() public {
        configureChain();
    }

    function testDepositWETH() public {
        if (block.chainid != 10) {
            revert("only for optimism");
        }
        VaultV2 vault = deployVaultV2();

        vm.deal(_owner, 100 ether);
        vm.deal(address(this), 100 ether);
        vm.startPrank(_owner);
        weth.deposit{value: 100 ether}();
        weth.approve(address(vault), 100 ether);
        vault.deposit(100 ether, _owner);
        console.log("owner's balanceOf vault share: ", vault.balanceOf(_owner));
        console.log("totalAssets", vault.totalAssets());
        console.log("totalSupply", vault.totalSupply());
        console.log("owner's balanceOf weth: ", weth.balanceOf(_owner));
        console.log("vault's balanceOf weth: ", weth.balanceOf(address(vault)));
        console.log(
            "vault's share of yield",
            yieldVault.balanceOf(address(vault))
        );
        console.log(
            "vault's available balance at deposit",
            vault.availableYieldBalance()
        );
        vm.warp(block.timestamp + 100 days);
        console.log(
            "vault's available balance after 100 days",
            vault.availableYieldBalance()
        );
    }

    function deployVaultV2() internal returns (VaultV2) {
        return
            new VaultV2(
                IERC20(address(weth)),
                "Spore WETH Vault",
                "spvWETH",
                twabController,
                yieldVault,
                _claimer,
                _yieldFeeRecipient,
                0,
                _owner
            );
    }

    function configureChain() internal {
        if (block.chainid == 10) {
            // Optimism mainnet
            // Underlying asset listed in the Aave Protocol
            // weth address
            weth = IWETH(0x4200000000000000000000000000000000000006);

            // yield vault(wrapped aave vault)
            yieldVault = IERC4626(0xB0f04cFB784313F97588F3D3be1b26C231122232);

            // twab controller
            twabController = TwabController(
                0x499a9F249ec4c8Ea190bebbFD96f9A83bf4F6E52
            );
        }
    }
}
