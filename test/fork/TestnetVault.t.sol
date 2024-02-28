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

contract ForkTestnetVault is Test {
    address _claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _yieldFeeRecipient = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;

    IERC4626 yieldVault;
    IERC20 UNDERLYING_ASSET_ADDRESS;
    IERC20 AToken;
    TwabController twabController;
    IFaucet faucet;

    function setUp() public {
        configureChain();
    }

    function testkWithdrawUSDC() public {
        VaultV2 vault = deployVaultV2();
        vm.deal(_owner, 100 ether);
        vm.deal(address(this), 100 ether);
        vm.startPrank(_owner);
        faucet.mint(address(UNDERLYING_ASSET_ADDRESS), _owner, 100);

        UNDERLYING_ASSET_ADDRESS.approve(address(vault), 100);
        vault.deposit(100, _owner);
        console.log("owner's balanceOf vault share: ", vault.balanceOf(_owner));
        assertEq(vault.totalAssets(), 100);
        assertEq(vault.totalSupply(), 100);

        vault.redeem(100, _owner, _owner);
        console.log("owner's balanceOf vault share: ", vault.balanceOf(_owner));
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(UNDERLYING_ASSET_ADDRESS.balanceOf(_owner), 100);
    }

    function testDepositUSDC() public {
        VaultV2 vault = deployVaultV2();

        vm.deal(_owner, 100 ether);
        vm.deal(address(this), 100 ether);
        vm.startPrank(_owner);
        faucet.mint(address(UNDERLYING_ASSET_ADDRESS), _owner, 100);

        UNDERLYING_ASSET_ADDRESS.approve(address(vault), 100);
        vault.deposit(100, _owner);
        console.log("owner's balanceOf vault share: ", vault.balanceOf(_owner));
        assertEq(vault.totalAssets(), 100);
        assertEq(vault.totalSupply(), 100);
        // "owner's balanceOf token"
        assertEq(UNDERLYING_ASSET_ADDRESS.balanceOf(_owner), 0);
        console.log(
            "vault's balanceOf weth: ",
            UNDERLYING_ASSET_ADDRESS.balanceOf(address(vault))
        );
        // "vault's share of yield"
        assertEq(yieldVault.balanceOf(address(vault)), 100);
        // "Vault's balance of AToken"
        assertEq(AToken.balanceOf(address(yieldVault)), 100);
        vm.warp(block.timestamp + 100 days);
        console.log(
            "vault's available balance after 100 days",
            vault.availableYieldBalance()
        );
    }

    function deployVaultV2() internal returns (VaultV2) {
        return
            new VaultV2(
                UNDERLYING_ASSET_ADDRESS,
                "Spore USDC Vault",
                "spvUSDC",
                twabController,
                yieldVault,
                _claimer,
                _yieldFeeRecipient,
                0,
                _owner
            );
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
            faucet = IFaucet(0x2c95d10bA4BBEc79e562e8B3f48687751808C925);
        }
    }
}
