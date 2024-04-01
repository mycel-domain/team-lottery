// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {TwabController} from "pt-v5-twab-controller/TwabController.sol";
import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin/interfaces/IERC4626.sol";
import "../../contracts/VaultV2.sol";
import "../interfaces/IWETH.sol";

contract ForkMainnetVault is Test {
    address _claimer = makeAddr("claimer");
    address _yieldFeeRecipient = makeAddr("yieldFeeRecipient");
    address _owner = makeAddr("owner");

    address public currentPrankee;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    address public user5 = makeAddr("user5");

    IWETH public weth;
    IERC4626 public yieldVault;
    TwabController public twabController;
    VaultV2 public vault;
    VaultV2.Team[] public teams;

    event PrizeDistributed(uint24 indexed drawId, address indexed recipient, uint256 amount);

    event DrawFinalized(uint24 indexed drawId, uint8[] winningTeams, uint256 winningRandomNumber, uint256 prizeSize);

    event PrizeClaimed(address indexed recipient, uint256 indexed amount);

    event NewDrawCreated(uint24 indexed drawId, uint256 indexed drawStartTime, uint256 indexed drawEndTime);

    function setUp() public {
        configureChain();
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
        vm.deal(_claimer, 10 ether);
        vm.deal(_owner, 10 ether);

        vm.startPrank(_owner);
        twabController = new TwabController(3600, uint32(block.timestamp));
        vault = _deployVaultV2();
        vm.stopPrank();
    }

    function testStartNextDraw() public {
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_claimer);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );

        vault.getDistributions(1);
        vault.distributePrizes(1);

        uint256 drawStartTime = block.timestamp + 1;
        uint256 drawEndTime = block.timestamp + 7 days;
        vm.expectEmit(true, true, true, true);
        emit NewDrawCreated(2, drawStartTime, drawEndTime);

        _startDrawPeriod(drawStartTime, drawEndTime);
        assertEq(vault.drawIsFinalized(1), true);
        assertEq(vault.drawIsFinalized(2), false);
        assertEq(vault.getDraw(2).drawStartTime, drawStartTime);
        assertEq(vault.getDraw(2).drawEndTime, drawEndTime);

        vm.stopPrank();
    }

    function testClaimPrize() public {
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_claimer);
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
        }

        vm.stopPrank();
    }

    function testDistributePrize() public {
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        vm.startPrank(_claimer);
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
        assertEq(vault.drawPrizeSet(1), true);
        vm.stopPrank();
    }

    function testFinalizeDraw() external {
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);
        _createTeams();

        uint8[] memory winningTeams = new uint8[](2);
        winningTeams[0] = 1;
        winningTeams[1] = 2;

        vm.expectEmit(true, false, false, false);
        emit DrawFinalized(
            1, winningTeams, 70333568669866340472331338725676123169611570254888405765691075355522696984357, 10 ether
        );
        vm.startPrank(_claimer);
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        assertEq(vault.drawIsFinalized(1), true);
        vm.stopPrank();
    }

    function testAvailableYield() public {
        uint256 balance = 1 ether;
        _wrap(user1, balance);
        _deposit(user1, balance);

        vm.warp(block.timestamp + 100 days);
        uint256 yield = vault.availableYieldBalance();
        assertEq(yield > 0, true);
    }

    function testDepositWETH() external {
        uint256 balance = 1 ether;
        _wrap(user1, balance);
        _deposit(user1, balance);

        assertEq(vault.balanceOf(user1), balance);
        assertEq(twabController.balanceOf(address(vault), user1), balance);
        assertEq(vault.totalSupply(), 1 ether);
    }

    function testkWithdrawWETH() external {
        uint256 balance = 1 ether;
        _wrap(user1, balance);
        _deposit(user1, balance);
        _withdraw(user1);

        assertEq(vault.balanceOf(user1), 0);
        assertEq(twabController.balanceOf(address(vault), user1), 0);
        assertEq(yieldVault.balanceOf(address(vault)), 0);
    }

    /* ============ Revert ============ */

    function testRevertInvalidRecipient() public {
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_claimer);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        vault.distributePrizes(1);

        vm.expectRevert(abi.encodeWithSelector(InvalidRecipient.selector, user5));
        _claimPrize(user5, 10 ether);
    }

    function testRevertInvalidAmount() public {
        _depositMultiUser();

        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_claimer);
        _createTeams();
        vault.finalizeDraw(
            1, 70333568669866340472331338725676123169611570254888405765691075355522696984357, abi.encode(teams)
        );
        vault.distributePrizes(1);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector));
        _claimPrize(user1, 1000 ether);
    }

    function testRevertDrawFinalized() public {
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_claimer);
        _createTeams();

        vault.finalizeDraw(1, 10, abi.encode(teams));
        vm.expectRevert(abi.encodeWithSelector(DrawAlreadyFinalized.selector, 1));
        vault.finalizeDraw(1, 10, abi.encode(teams));
        vm.stopPrank();
    }

    function testRevertRandomNumberIsZero() public {
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_claimer);
        _createTeams();

        vm.expectRevert(abi.encodeWithSelector(RandomNumberIsZero.selector));
        vault.finalizeDraw(1, 0, abi.encode(teams));
        vm.stopPrank();
    }

    function testRevertPrizeAlreadySet() public {
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_claimer);
        _createTeams();

        vault.finalizeDraw(1, 10, abi.encode(teams));
        vault.distributePrizes(1);
        vm.expectRevert(abi.encodeWithSelector(PrizeAlreadySet.selector, 1));
        vault.distributePrizes(1);
        vm.stopPrank();
    }

    function testRevertDrawNotFinalized() public {
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_claimer);
        _createTeams();
        vm.expectRevert(abi.encodeWithSelector(DrawNotFinalized.selector, 1));
        vault.distributePrizes(1);
        vm.stopPrank();
    }

    function testRevertStartPeriod() public {
        vm.expectRevert(abi.encodeWithSelector(DrawNotFinalized.selector, 1));
        uint256 drawStartTime = block.timestamp + 1;
        uint256 drawEndTime = block.timestamp + 7 days;

        _startDrawPeriod(drawStartTime, drawEndTime);
        vm.stopPrank();
    }

    function testRevertCallerNotClaimer() public {
        _depositMultiUser();
        vm.warp(vault.getDraw(1).drawEndTime);

        vm.startPrank(_owner);
        _createTeams();
        vm.expectRevert(abi.encodeWithSelector(CallerNotClaimer.selector, _owner, _claimer));
        vault.finalizeDraw(1, 10, abi.encode(teams));
        vm.stopPrank();
    }

    /* ============ internal functions ============ */
    function _deployVaultV2() internal returns (VaultV2) {
        return new VaultV2(
            IERC20(address(weth)),
            "Spore USDC Vault",
            "spvUSDC",
            twabController,
            IERC4626(address(yieldVault)),
            _claimer,
            _yieldFeeRecipient,
            0,
            _owner
        );
    }

    function _startDrawPeriod(uint256 startTime, uint256 endTime) internal prankception(_claimer) {
        vault.startDrawPeriod(startTime, endTime);
    }

    function _claimPrize(address account, uint256 amount) internal prankception(account) {
        vault.claimPrize(amount);
    }

    function _wrap(address caller, uint256 amount) internal prankception(caller) {
        weth.deposit{value: amount}();
        weth.approve(address(vault), amount);
    }

    function _deposit(address account, uint256 amount) internal prankception(account) {
        vault.deposit(amount, account);
    }

    function _depositMultiUser() internal {
        uint256 balance = 1 ether;
        _wrap(user1, balance);
        _wrap(user2, balance);
        _wrap(user3, balance);
        _wrap(user4, balance);
        _deposit(user1, balance);
        vm.warp(block.timestamp + 1);
        _deposit(user2, balance);
        _deposit(user3, balance);
        _deposit(user4, balance);
    }

    function _withdraw(address account) internal prankception(account) {
        uint256 balance = vault.maxWithdraw(account);
        vault.withdraw(balance, account, account);
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

    function configureChain() internal {
        if (block.chainid == 10) {
            // Optimism mainnet
            // Underlying asset listed in the Aave Protocol
            // weth address
            weth = IWETH(0x4200000000000000000000000000000000000006);

            // yield vault(wrapped aave vault)
            yieldVault = IERC4626(0xB0f04cFB784313F97588F3D3be1b26C231122232);

            // twab controller
            // twabController = TwabController(0x499a9F249ec4c8Ea190bebbFD96f9A83bf4F6E52);
        }
    }
}
