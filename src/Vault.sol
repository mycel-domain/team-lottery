// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC20Permit, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "owner-manager-contracts/Ownable.sol";

import {PrizePool} from "./PrizePool.sol";

contract Vault is ERC20, ERC20Permit, Ownable {
    /// @notice Address of the ERC4626 vault generating yield.
    IERC4626 private immutable _yieldVault;

    /// @notice Address of the PrizePool that computes prizes.
    PrizePool private immutable _prizePool;

    /// @notice Address of the underlying asset used by the Vault.
    IERC20 private immutable _asset;

    using Math for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        IERC4626 yieldVault_,
        PrizePool prizePool_,
        address owner_
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(owner_) {
        _asset = asset_;
        _yieldVault = yieldVault_;
        _prizePool = prizePool_;
    }
}
