// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract PrizePool {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
}
