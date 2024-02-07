// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC20Permit, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "owner-manager-contracts/Ownable.sol";

contract Vault {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
}
