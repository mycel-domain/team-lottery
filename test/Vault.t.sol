// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {SD59x18, sd, unwrap, convert} from "prb-math/SD59x18.sol";

import "../src/VaultV2.sol";
import "../src/testnet/ERC20Mintable.sol";
import "../src/testnet/TokenFaucet.sol";
import "../src/testnet/YieldVaultMintRate.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IFaucet.sol";

contract VaultTest is Test {
    address _claimer = makeAddr("claimer");
    address _yieldFeeRecipient = makeAddr("yieldFeeRecipient");
    address currentPrankee;

    address _owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");
    uint256 internal constant ONE_YEAR_IN_SECONDS = 31557600;

    VaultV2 vault;
    TwabController twabController;
    ERC20Mintable asset;
    TokenFaucet faucet;
    YieldVaultMintRate yieldVaultMintRate;

    function setUp() public {
        vm.startPrank(_owner);
        asset = new ERC20Mintable("USDC", "USDC", 6, _owner);
        faucet = new TokenFaucet();
        yieldVaultMintRate = new YieldVaultMintRate(asset, "Spore USDC Yield Vault", "syvUSDC", _owner);
        twabController = new TwabController(3600, uint32(block.timestamp));
        vault = deployVaultV2();

        asset.grantRole(asset.MINTER_ROLE(), address(yieldVaultMintRate));
        yieldVaultMintRate.setRatePerSecond(250000000000000000 / ONE_YEAR_IN_SECONDS);

        vm.stopPrank();

        _mintMintable(address(faucet));
        _grantMinterRoleAsset(user1);
        _grantMinterRoleAsset(user2);
        _grantMinterRoleAsset(user3);
        _grantMinterRoleAsset(user4);
        _grantMinterRoleAsset(user5);
    }

    function testAvailableYield() public {
        _mintMintable(user1);
        uint256 balance = 100 ether;
        _deposit(user1, balance);

        vm.warp(block.timestamp + 100 days);
        vm.startPrank(_owner);
        console.log("total Assets: ", vault.totalAssets());
        console.log("total Supply: ", vault.totalSupply());
        console.log("total amount of yield", yieldVaultMintRate.balanceOf(address(vault)));

        yieldVaultMintRate.yield(10e18);
        console.log("available yield balance", vault.availableYieldBalance());
        assertEq(vault.availableYieldBalance() > 0, true);
        vm.stopPrank();
    }

    function testDeposit() public {
        _mintMintable(user1);
        uint256 balance = 100 ether;

        _deposit(user1, balance);

        assertEq(vault.balanceOf(user1), balance);
        assertEq(twabController.balanceOf(address(vault), user1), balance);
        assertEq(asset.balanceOf(address(yieldVaultMintRate)), balance);
        assertEq(yieldVaultMintRate.balanceOf(address(vault)), balance);
    }

    function testWithdraw() public {
        _mintMintable(user1);
        uint256 balance = 100 ether;

        _deposit(user1, asset.balanceOf(user1));
        _withdraw(user1);

        assertEq(asset.balanceOf(user1), balance);
        assertEq(vault.balanceOf(user1), 0);
        assertEq(twabController.balanceOf(address(vault), user1), 0);
        assertEq(asset.balanceOf(address(yieldVaultMintRate)), 0);
        assertEq(yieldVaultMintRate.balanceOf(address(vault)), 0);
    }

    function testRatePerSecond() public {
        vm.startPrank(_owner);
        uint256 ratePerSecond = 250000000000000000;
        yieldVaultMintRate.setRatePerSecond(ratePerSecond / ONE_YEAR_IN_SECONDS);
        assertEq(yieldVaultMintRate.ratePerSecond(), ratePerSecond / ONE_YEAR_IN_SECONDS);
        vm.stopPrank();
    }

    function deployVaultV2() internal returns (VaultV2) {
        return new VaultV2(
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

    function _deposit(address account, uint256 amount) internal prankception(account) {
        asset.approve(address(vault), amount);
        vault.deposit(amount, account);
    }

    function _withdraw(address account) internal prankception(account) {
        uint256 balance = vault.maxWithdraw(account);
        vault.withdraw(balance, account, account);
    }

    function _mintMintable(address account) internal prankception(_owner) {
        asset.mint(account, 100 ether);
    }

    function _grantMinterRoleAsset(address account) internal prankception(_owner) {
        asset.grantRole(asset.MINTER_ROLE(), account);
    }

    function _faucet(address account) internal prankception(account) {
        faucet.drip(IERC20(address(asset)));
    }

    modifier prankception(address prankee) {
        address prankBefore = currentPrankee;
        vm.stopPrank();
        vm.startPrank(prankee);
        _;
        vm.stopPrank();
        if (prankBefore != address(0)) {
            vm.startPrank(prankBefore);
        }
    }
}
