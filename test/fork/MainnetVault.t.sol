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

contract ForkMainnetVault is Test {
    address _claimer = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _yieldFeeRecipient = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;
    address _owner = 0x06aa005386F53Ba7b980c61e0D067CaBc7602a62;

    address m1 = address(5);
    address m2 = address(2);
    address m3 = address(3);
    address m4 = address(4);

    IWETH public weth;
    IERC4626 public yieldVault;
    IERC20 public AToken;
    TwabController public twabController;

    function setUp() public {
        configureChain();
    }

    function test_finalizeDraw() public {
        VaultV2 vault = deployVaultV2();

        vm.startPrank(_owner);
        vm.deal(address(this), 100 ether);
        vault.startDrawPeriod(block.timestamp);
        vm.stopPrank();

        depositETH(vault);

        vm.startPrank(_owner);
        vm.warp(block.timestamp + 7 days + 3600);

        address[] memory team1 = new address[](2);
        team1[0] = m1;
        team1[1] = m2;
        address[] memory team2 = new address[](2);
        team2[0] = m3;
        team2[1] = m4;

        VaultV2.Team[] memory teams = new VaultV2.Team[](2);

        uint256 team1Twab = vault.calculateTeamTwabBetween(team1, 1);
        uint256 team2Twab = vault.calculateTeamTwabBetween(team2, 1);

        teams[0] = VaultV2.Team({
            teamId: 1,
            teamTwab: team1Twab,
            teamPoints: 150,
            // teamContributionFraction: TIER_ODDS_1_5,
            teamMembers: team1
        });

        teams[1] = VaultV2.Team({
            teamId: 2,
            teamTwab: team2Twab,
            teamPoints: 100,
            // teamContributionFraction: TIER_ODDS_1_6,
            teamMembers: team2
        });

        bytes32 merkleRoot = 0x7bb77316f26ea3988566a27acebe392e2c26f95134b9552dc31b01bd8e151fd2;
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );

        (address[] memory prizeRecipients, uint256[] memory prizeAmounts) = vault.getDistributions(1);

        vault.setDistribution(1, merkleRoot);
        /**
         * bytes32[] memory m1Proof = new bytes32[](2);
         *     m1Proof[
         *         0
         *     ] = 0xcdf69a3fbe2fece0bfb7d11a4b19935a2000d94dfe45628438f0f51d96038e32;
         *     m1Proof[
         *         1
         *     ] = 0xcd513ac65595a628994bb4adb3fea5f09212a334d42eb531c142b4c4153e42d7;
         *
         *     bytes32[] memory m2Proof = new bytes32[](2);
         *     m2Proof[
         *         0
         *     ] = 0xd08c889a2b804c67887cd70e57ff036e6bc341281711f6587c117607d171d093;
         *     m2Proof[
         *         1
         *     ] = 0xcef176f06c08cd4d427835200fd74838135532147a2b74b603fcb420e80fd07a;
         *
         *     bytes32[] memory m3Proof = new bytes32[](2);
         *     m3Proof[
         *         0
         *     ] = 0xf8d15571a64548fa203ae0cb922ffbcc7cdcad943ff1486b7bdf772f9b266784;
         *     m3Proof[
         *         1
         *     ] = 0xcd513ac65595a628994bb4adb3fea5f09212a334d42eb531c142b4c4153e42d7;
         *
         *     bytes32[] memory m4Proof = new bytes32[](2);
         *     m4Proof[
         *         0
         *     ] = 0x7a7aad01405ef67cbfbdf791aef4b96a1da0f0235e1c893b9d9f90ace9aa2aba;
         *     m4Proof[
         *         1
         *     ] = 0xcef176f06c08cd4d427835200fd74838135532147a2b74b603fcb420e80fd07a;
         *
         *     VaultV2.Distribution[]
         *         memory distributions = new VaultV2.Distribution[](4);
         *     distributions[0] = VaultV2.Distribution({
         *         recipient: m1,
         *         index: 0,
         *         amount: prizeAmounts[0],
         *         merkleProof: m1Proof
         *     });
         *     distributions[1] = VaultV2.Distribution({
         *         recipient: m2,
         *         index: 1,
         *         amount: prizeAmounts[1],
         *         merkleProof: m2Proof
         *     });
         *     distributions[2] = VaultV2.Distribution({
         *         recipient: m3,
         *         index: 2,
         *         amount: prizeAmounts[2],
         *         merkleProof: m3Proof
         *     });
         *     distributions[3] = VaultV2.Distribution({
         *         recipient: m4,
         *         index: 3,
         *         amount: prizeAmounts[3],
         *         merkleProof: m4Proof
         *     });
         *
         *     // TODO: check why distribution amount differ from each test
         *
         *     // vault.distributePrizes(1, abi.encode(distributions));
         */
    }

    function depositETH(VaultV2 vault) public payable {
        vm.deal(m1, 100 ether);
        vm.deal(m2, 100 ether);
        vm.deal(m3, 100 ether);
        vm.deal(m4, 100 ether);

        vm.startPrank(m1);
        weth.deposit{value: 100 ether}();
        weth.approve(address(vault), 100 ether);
        vault.deposit(100 ether, m1);
        vm.warp(block.timestamp + 1);

        vm.stopPrank();

        vm.startPrank(m2);
        weth.deposit{value: 100 ether}();
        weth.approve(address(vault), 100 ether);
        vault.deposit(10 ether, m2);
        vm.stopPrank();

        vm.startPrank(m3);
        weth.deposit{value: 50 ether}();
        weth.approve(address(vault), 50 ether);
        vault.deposit(50 ether, m3);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(m4);
        weth.deposit{value: 100 ether}();
        weth.approve(address(vault), 100 ether);
        vault.deposit(100 ether, m4);
        vm.stopPrank();
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
        console.log("vault's share of yield", yieldVault.balanceOf(address(vault)));
        console.log("vault's available balance at deposit", vault.availableYieldBalance());
        vm.warp(block.timestamp + 100 days);
        console.log("vault's available balance after 100 days", vault.availableYieldBalance());
    }

    function testkWithdrawWETH() public {
        VaultV2 vault = deployVaultV2();
        vm.deal(_owner, 100 ether);
        vm.deal(address(this), 100 ether);
        vm.startPrank(_owner);
        weth.deposit{value: 10 ether}();
        weth.approve(address(vault), 10 ether);
        vault.deposit(10 ether, _owner);

        console.log("owner's balanceOf vault share: ", vault.balanceOf(_owner));

        vm.warp(block.timestamp + 100 days);
        vault.withdraw(vault.maxWithdraw(_owner), _owner, _owner);
        assertEq(vault.totalSupply(), 0);
        assertEq(weth.balanceOf(_owner), 10 ether);
        console.log("owner's balanceOf weth: ", weth.balanceOf(_owner));
        console.log("vault's available balance after 100 days", vault.availableYieldBalance());
        assertEq(vault.totalAssets(), vault.availableYieldBalance());
    }

    function deployVaultV2() internal returns (VaultV2) {
        return new VaultV2(
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
            twabController = TwabController(0x499a9F249ec4c8Ea190bebbFD96f9A83bf4F6E52);
        }
    }
}
