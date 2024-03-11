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
    VaultV2.Distribution[] distributions;

    struct Value {
        uint256 index;
        address recipient;
        uint256 amount;
    }

    event PrizeDistributed(uint24 indexed drawId, address indexed recipient, uint256 amount);
    event DistributionSet(uint24 indexed drawId, bytes32 merkleRoot);
    event DrawFinalized(uint24 indexed drawId, uint8[] winningTeams, uint256 winningRandomNumber);

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

    function testDistributePrize() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawStartTime + vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10e18);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        (address[] memory prizeRecipients, uint256[] memory prizeAmounts) = vault.getDistributions(1);
        // _genareteMerkleRoot(prizeRecipients, prizeAmounts);
        _createDistributions(prizeAmounts);

        vm.expectEmit(true, false, false, true);
        emit DistributionSet(1, root);
        vault.setDistribution(1, root);

        for (uint256 i = 0; i < prizeRecipients.length; i++) {
            vm.expectEmit(true, true, false, true);
            emit PrizeDistributed(1, prizeRecipients[i], prizeAmounts[i]);
        }

        vault.distributePrizes(1, abi.encode(distributions));
        vm.stopPrank();
    }

    function testFinalizeDraw() public {
        vm.startPrank(_owner);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawStartTime + vault.getDraw(1).drawEndTime);
        vm.startPrank(_owner);
        yieldVaultMintRate.yield(10e18);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        vault.getDistributions(1);
        vm.stopPrank();
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

    function _createDistributions(uint256[] memory prizeAmounts) internal {
        /**
         * const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
         *   const values = [
         * [0, "0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF", "2499999999999999999"],
         * [1, "0x537C8f3d3E18dF5517a58B3fB9D9143697996802", "2499999999999999999"],
         * [2, "0xc0A55e2205B289a967823662B841Bd67Aa362Aec", "2499999999999999999"],
         * [3, "0x90561e5Cd8025FA6F52d849e8867C14A77C94BA0", "2499999999999999999"],
         *   ];
         *
         *   const tree = StandardMerkleTree.of(values, ["uint256", "address", "uint256"]);
         *
         *   console.log("Merkle Root:", tree.root);
         *
         *   console.log(tree.getProof(0));
         *   console.log(tree.getProof(1));
         *   console.log(tree.getProof(2));
         *   console.log(tree.getProof(3));
         */
        distributions = new VaultV2.Distribution[](4);

        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x66654d4622fd727d039303f2d65d489138e4c67f8090cfda99a4ec8d631cb1a7;
        proof1[1] = 0x256fb73c97423b8a2dc74620294eecf7d5806078f81d0bea6165a5ea663846ad;

        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = 0xc97d404efca71f529c663bad99a543566e9a26460291722535552b23d546ddd5;
        proof2[1] = 0xab793567a22c6c92e245d6d1ab15631d8400ad02b541d76a1d28b78d1834369c;

        bytes32[] memory proof3 = new bytes32[](2);
        proof3[0] = 0x14949dd0480fd5a956ef42cadaa4981aeef981cc4ad2b109470f41a2572c4959;
        proof3[1] = 0x256fb73c97423b8a2dc74620294eecf7d5806078f81d0bea6165a5ea663846ad;

        bytes32[] memory proof4 = new bytes32[](2);
        proof4[0] = 0x942cd955def08d3c1d45677755bc03645568fb3093bc08a40df307552f1e65aa;
        proof4[1] = 0xab793567a22c6c92e245d6d1ab15631d8400ad02b541d76a1d28b78d1834369c;

        distributions[0] =
            VaultV2.Distribution({recipient: user1, index: 0, amount: prizeAmounts[0], merkleProof: proof1});
        distributions[1] =
            VaultV2.Distribution({recipient: user2, index: 1, amount: prizeAmounts[1], merkleProof: proof2});
        distributions[2] =
            VaultV2.Distribution({recipient: user3, index: 2, amount: prizeAmounts[2], merkleProof: proof3});
        distributions[3] =
            VaultV2.Distribution({recipient: user4, index: 3, amount: prizeAmounts[3], merkleProof: proof4});
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
