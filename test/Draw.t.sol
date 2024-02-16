// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Draw} from "../src/Draw.sol";

contract DrawTest is Test {
    Draw public draw;

    function setUp() public {
        draw = new Draw();
    }

    function test_CalculatePseudoRandomNumber() public {
        uint24 drawId = 1;
        address vault = address(0x1);
        address user = address(0x2);
        uint8 tier = 3;
        uint32 prizeIndex = 4;
        uint256 winningRandomNumber = 5;
        uint256 pseudoRandomNumber = draw.calculatePseudoRandomNumber(
            drawId,
            vault,
            user,
            tier,
            prizeIndex,
            winningRandomNumber
        );

        assertEq(
            pseudoRandomNumber,
            uint256(
                keccak256(
                    abi.encode(
                        drawId,
                        vault,
                        user,
                        tier,
                        prizeIndex,
                        winningRandomNumber
                    )
                )
            )
        );
    }
}
