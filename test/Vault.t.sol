// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {SD59x18, sd, unwrap, convert} from "prb-math/SD59x18.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";

import "../src/VaultV2.sol";
import "../src/testnet/ERC20Mintable.sol";
import "../src/testnet/TokenFaucet.sol";
import "../src/testnet/YieldVaultMintRate.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IFaucet.sol";

contract VaultTest is Test {
    address _claimer = makeAddr("claimer");
    address _yieldFeeRecipient = makeAddr("yieldFeeRecipient");
    address public currentPrankee;

    address _owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    address public user5 = makeAddr("user5");
    uint256 public constant ONE_YEAR_IN_SECONDS = 31557600;

    bytes32 public root = 0xb2e75e0d42dc18d06e0a2f5b5ffc8da9a930eb8e674c5d63070384e1084f8763;
    bytes32[] public leafs;
    bytes32[] public l2;

    VaultV2 public vault;
    TwabController public twabController;
    ERC20Mintable public asset;
    TokenFaucet public faucet;
    YieldVaultMintRate public yieldVaultMintRate;
    VaultV2.Team[] public teams;

    struct Value {
        uint256 index;
        address recipient;
        uint256 amount;
    }

    event PrizeDistributed(uint24 indexed drawId, address indexed recipient, uint256 amount);

    event DrawFinalized(uint24 indexed drawId, uint8[] winningTeams, uint256 winningRandomNumber, uint256 prizeSize);

    event PrizeClaimed(address indexed recipient, uint256 indexed amount);

    function setUp() public {
        vm.startPrank(_owner);
        asset = new ERC20Mintable("USDC", "USDC", 6, _owner);
        faucet = new TokenFaucet();
        yieldVaultMintRate = new YieldVaultMintRate(asset, "Spore USDC Yield Vault", "syvUSDC", _owner);
        twabController = new TwabController(3600, uint32(block.timestamp));
        vault = _deployVaultV2();

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

    /* ============ Draw Functions ============ */

    function testClaimPrize() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);

        yieldVaultMintRate.yield(10 ether);

        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );

        vault.distributePrizes(1);
        (address[] memory prizeRecipients, uint256[] memory prizeAmounts) = vault.getDistributions(1);

        for (uint256 i = 0; i < prizeRecipients.length; i++) {
            assertEq(vault._claimablePrize(prizeRecipients[i]), prizeAmounts[i]);
            vm.expectEmit(true, true, false, true);
            emit PrizeClaimed(prizeRecipients[i], prizeAmounts[i]);
            _claimPrize(prizeRecipients[i], prizeAmounts[i]);
            assertEq(vault._claimablePrize(prizeRecipients[i]), 0);
            assertEq(asset.balanceOf(prizeRecipients[i]), prizeAmounts[i]);
        }

        vm.stopPrank();
    }

    function testDistributePrize() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10e18);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );

        (address[] memory prizeRecipients, uint256[] memory prizeAmounts) = vault.getDistributions(1);

        for (uint256 i = 0; i < prizeRecipients.length; i++) {
            vm.expectEmit(true, true, false, true);
            emit PrizeDistributed(1, prizeRecipients[i], prizeAmounts[i]);
        }

        vault.distributePrizes(1);
        assertEq(vault.drawIsFinalized(1), true);
        assertEq(vault.drawIsFinalized(1), true);
        vm.stopPrank();
    }

    function testFinalizeDraw() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10 ether);
        _createTeams();

        uint8[] memory winningTeams = new uint8[](2);
        winningTeams[0] = 1;
        winningTeams[1] = 2;

        vm.expectEmit(true, false, false, false);
        emit DrawFinalized(
            1, winningTeams, 70333568669866340472331338725676123169611570254888405765691075355522696984357, 10 ether
        );
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        assertEq(vault.drawIsFinalized(1), true);

        vm.stopPrank();
    }

    function testAvailableYield() public {
        _mintMintable(user1);
        uint256 balance = 100 ether;
        _deposit(user1, balance);

        vm.warp(block.timestamp + 100 days);
        vm.startPrank(_owner);

        yieldVaultMintRate.yield(10e18);
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

    /* ============ Revert ============ */

    function testRevertInvalidRecipient() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10 ether);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        vault.distributePrizes(1);

        vm.expectRevert(abi.encodeWithSelector(InvalidRecipient.selector, user5));
        _claimPrize(user5, 10 ether);
    }

    function testRevertInvalidAmount() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10 ether);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        vault.distributePrizes(1);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector));
        _claimPrize(user1, 1000 ether);
    }

    /* TODO:TimestampNotFinalized
    function testRevertInvalidDrawPeriod() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime - 1 days);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10 ether);
        _createTeams();

        vm.expectRevert(
            abi.encodeWithSelector(InvalidDrawPeriod.selector, block.timestamp, vault.getDraw(1).drawEndTime)
        );
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );

        vm.stopPrank();
    }
    */

    function testRevertDrawFinalized() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10 ether);
        _createTeams();

        vault.finalizeDraw(1, 10, abi.encode(teams));
        vm.expectRevert(abi.encodeWithSelector(DrawAlreadyFinalized.selector, 1));
        vault.finalizeDraw(1, 10, abi.encode(teams));
        vm.stopPrank();
    }

    function testRevertRandomNumberIsZero() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10 ether);
        _createTeams();

        vm.expectRevert(abi.encodeWithSelector(RandomNumberIsZero.selector));
        vault.finalizeDraw(1, 0, abi.encode(teams));
        vm.stopPrank();
    }

    function testRevertPrizeAlreadySet() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10e18);
        _createTeams();
        vault.finalizeDraw(1, 10, abi.encode(teams));
        vault.distributePrizes(1);
        vm.expectRevert(abi.encodeWithSelector(PrizeAlreadySet.selector, 1));
        vault.distributePrizes(1);
        vm.stopPrank();
    }

    function testRevertDrawNotFinalized() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10e18);
        _createTeams();
        vm.expectRevert(abi.encodeWithSelector(DrawNotFinalized.selector, 1));
        vault.distributePrizes(1);
        vm.stopPrank();
    }

    /* ============ internal functions ============ */

    function _deployVaultV2() internal returns (VaultV2) {
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

    function _depositMultiUser() internal {
        uint256 balance = 100 ether;
        _mintMintable(user1);
        _deposit(user1, balance);
        _mintMintable(user2);
        _deposit(user2, balance);
        _mintMintable(user3);
        _deposit(user3, balance);
        _mintMintable(user4);
        _deposit(user4, balance);
        // _mintMintable(user5);
        // _deposit(user5, balance);
    }

    function _claimPrize(address account, uint256 amount) internal prankception(account) {
        vault.claimPrize(amount);
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

    function _genareteMerkleRoot(address[] memory prizeRecipients, uint256[] memory prizeAmounts) internal {
        Value[] memory values = new Value[](prizeRecipients.length);

        for (uint256 i = 0; i < prizeRecipients.length; i++) {
            values[i] = Value({index: i, recipient: prizeRecipients[i], amount: prizeAmounts[i]});
        }
        for (uint256 i = 0; i < values.length; i++) {
            leafs.push(
                keccak256(bytes.concat(keccak256(abi.encode(values[i].index, values[i].recipient, values[i].amount))))
            );
        }

        for (uint256 i = 0; i < leafs.length; i += 2) {
            l2.push(keccak256(abi.encodePacked(leafs[i], leafs[i + 1])));
        }
        root = keccak256(abi.encodePacked(l2[0], l2[1]));
    }

    function _createTeams() internal {
        teams = new VaultV2.Team[](2);
        address[] memory team1 = new address[](2);
        team1[0] = user1;
        team1[1] = user2;
        address[] memory team2 = new address[](2);
        team2[0] = user3;
        team2[1] = user4;

        uint256 team1Twab = vault.calculateTeamTwabBetween(team1, 1);
        uint256 team2Twab = vault.calculateTeamTwabBetween(team2, 1);
        teams[0] = VaultV2.Team({teamId: 1, teamTwab: team1Twab, teamPoints: 150, teamMembers: team1});
        teams[1] = VaultV2.Team({teamId: 2, teamTwab: team2Twab, teamPoints: 100, teamMembers: team2});
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
