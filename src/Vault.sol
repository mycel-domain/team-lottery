// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20, IERC20, IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {ERC20Permit, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Ownable} from "owner-manager-contracts/Ownable.sol";
import {TwabController, SPONSORSHIP_ADDRESS} from "pt-v5-twab-controller/TwabController.sol";

import {IVault} from "./interface/IVault.sol";
import {Draw} from "./Draw.sol";

contract Vault is IERC4626, ERC20Permit, Ownable, IVault {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /// The maximum amount of shares that can be minted.
    uint256 private constant _UINT96_MAX = type(uint96).max;

    /// @notice Underlying asset decimals.
    uint8 private immutable _underlyingDecimals;

    /// @notice Address of the ERC4626 vault generating yield.
    IERC4626 private immutable _yieldVault;

    /// @notice Address of the underlying asset used by the Vault.
    IERC20 private immutable _asset;

    /// @notice Address of the TwabController used to keep track of balances.
    TwabController private immutable _twabController;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        TwabController twabController_,
        IERC4626 yieldVault_,
        address claimer_,
        address yieldFeeRecipient_,
        uint256 yieldFeePercentage_,
        address owner_
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(owner_) {
        _asset = asset_;
        _yieldVault = yieldVault_;
        _twabController = twabController_;

        emit NewVault(
            asset_,
            name_,
            symbol_,
            twabController_,
            yieldVault_,
            claimer_,
            yieldFeeRecipient_,
            yieldFeePercentage_,
            owner_
        );
    }

    /* ============ ERC20 / ERC4626 functions ============ */

    /// @inheritdoc IERC4626
    function asset() external view virtual override returns (address) {
        return address(_asset);
    }

    /// @inheritdoc ERC20
    function balanceOf(address _account) public view virtual override(ERC20, IERC20) returns (uint256) {
        return _balanceOf(_account);
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _underlyingDecimals;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual override returns (uint256) {
        return _totalAssets();
    }

    /// @inheritdoc ERC20
    function totalSupply() public view virtual override(ERC20, IERC20) returns (uint256) {
        return _totalSupply();
    }
    /* ============ Deposit Functions ============ */
    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */

    function deposit(uint256 assets, address receiver) external returns (uint256) {
        return _deposit(msg.sender, receiver, assets);
    }

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    /**
     * @inheritdoc IERC4626
     * @dev Will revert if the Vault is under-collateralized.
     */
    function mint(uint256 _shares, address _receiver) external virtual override returns (uint256) {
        return _deposit(msg.sender, _receiver, _shares);
    }

    /* ============ Withdraw Functions ============ */
    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner) external virtual override returns (uint256) {
        if (_assets > _maxWithdraw(_owner)) {
            revert WithdrawMoreThanMax(_owner, _assets, _maxWithdraw(_owner));
        }

        uint256 _depositedAssets = _totalSupply();
        uint256 _withdrawableAssets = _totalAssets();
        bool _vaultCollateralized = _isVaultCollateralized(_depositedAssets, _withdrawableAssets);

        uint256 _shares = _vaultCollateralized
            ? _assets
            : _convertToShares(_assets, _depositedAssets, _withdrawableAssets, Math.Rounding.Up);

        uint256 _withdrawnAssets = _redeem(msg.sender, _receiver, _owner, _shares, _assets, _vaultCollateralized);

        if (_withdrawnAssets < _assets) revert WithdrawAssetsLTRequested(_assets, _withdrawnAssets);

        return _shares;
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner) external virtual override returns (uint256) {
        if (_shares > _maxRedeem(_owner)) revert RedeemMoreThanMax(_owner, _shares, _maxRedeem(_owner));

        uint256 _depositedAssets = _totalSupply();
        uint256 _withdrawableAssets = _totalAssets();
        bool _vaultCollateralized = _isVaultCollateralized(_depositedAssets, _withdrawableAssets);

        uint256 _assets = _convertToAssets(_shares, _depositedAssets, _withdrawableAssets, Math.Rounding.Down);

        return _redeem(msg.sender, _receiver, _owner, _shares, _assets, _vaultCollateralized);
    }
    /* ============ Conversion Functions ============ */

    /// @inheritdoc IERC4626
    function convertToShares(uint256 _assets) external view virtual override returns (uint256) {
        return _convertToShares(_assets, _totalSupply(), _totalAssets(), Math.Rounding.Down);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 _shares) external view virtual override returns (uint256) {
        return _convertToAssets(_shares, _totalSupply(), _totalAssets(), Math.Rounding.Down);
    }

    /* ============ Max / Preview Functions ============ */

    /// @inheritdoc IERC4626
    function maxDeposit(address) external view virtual override returns (uint256) {
        uint256 _depositedAssets = _totalSupply();
        return _isVaultCollateralized(_depositedAssets, _totalAssets()) ? _maxDeposit(_depositedAssets) : 0;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 _assets) external view virtual override returns (uint256) {
        return _convertToShares(_assets, _totalSupply(), _totalAssets(), Math.Rounding.Down);
    }

    /// @inheritdoc IERC4626
    function maxMint(address) external view virtual override returns (uint256) {
        uint256 _depositedAssets = _totalSupply();
        return _isVaultCollateralized(_depositedAssets, _totalAssets()) ? _maxDeposit(_depositedAssets) : 0;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 _shares) external view virtual override returns (uint256) {
        return _convertToAssets(_shares, _totalSupply(), _totalAssets(), Math.Rounding.Up);
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address _owner) external view virtual override returns (uint256) {
        return _maxWithdraw(_owner);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 _assets) external view virtual override returns (uint256) {
        return _convertToShares(_assets, _totalSupply(), _totalAssets(), Math.Rounding.Up);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address _owner) external view virtual override returns (uint256) {
        return _maxRedeem(_owner);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) external view virtual override returns (uint256) {
        return _convertToAssets(_shares, _totalSupply(), _totalAssets(), Math.Rounding.Down);
    }

    /* ============================================ */
    /* ============ Internal Functions ============ */
    /* ============================================ */

    /* ============ ERC20 / ERC4626 functions ============ */
    /**
     * @notice Fetch underlying asset decimals.
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     * @param asset_ Address of the underlying asset
     * @return bool True if the attempt was successful, false otherwise
     * @return uint8 Token decimals number
     */
    function _tryGetAssetDecimals(IERC20 asset_) private view returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) =
            address(asset_).staticcall(abi.encodeWithSelector(IERC20Metadata.decimals.selector));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    /**
     * @notice Get the Vault shares balance of a given account.
     * @param _account Account to get the balance for
     * @return uint256 Balance of the account
     */
    function _balanceOf(address _account) internal view returns (uint256) {
        return _twabController.balanceOf(address(this), _account);
    }

    /**
     * @notice Total amount of assets managed by this Vault.
     * @return uint256 Total amount of assets
     */
    function _totalAssets() internal view returns (uint256) {
        return _yieldVault.maxWithdraw(address(this));
    }

    /**
     * @notice Total amount of shares minted by this Vault.
     * @return uint256 Total amount of shares
     */
    function _totalSupply() internal view returns (uint256) {
        return _twabController.totalSupply(address(this));
    }

    /* ============ Deposit Functions ============ */

    function _deposit(address _caller, address _receiver, uint256 _assets) internal returns (uint256) {
        // It is only possible to deposit when the vault is collateralized
        // Shares are backed 1:1 by assets
        if (_assets == 0) revert MintZeroShares();

        _yieldVault.deposit(_assets, address(this));
        _mint(_receiver, _assets);
        emit Deposit(_caller, _receiver, _assets, _assets);
        return _assets;
    }

    /* ============ Max / Preview Functions ============ */

    /**
     * @notice Returns the maximum amount of underlying assets that can be deposited into the Vault.
     * @dev We use type(uint96).max cause this is the type used to store balances in TwabController.
     * @param _depositedAssets Assets deposited into the YieldVault
     * @return uint256 Amount of underlying assets that can be deposited
     */
    function _maxDeposit(uint256 _depositedAssets) internal view returns (uint256) {
        uint256 _vaultMaxDeposit = _UINT96_MAX - _depositedAssets;
        uint256 _yieldVaultMaxDeposit = _yieldVault.maxDeposit(address(this));

        // Vault shares are minted 1:1 when the vault is collateralized,
        // so maxDeposit and maxMint return the same value
        return _yieldVaultMaxDeposit < _vaultMaxDeposit ? _yieldVaultMaxDeposit : _vaultMaxDeposit;
    }

    /**
     * @notice Returns the maximum amount of the underlying asset that can be withdrawn
     * from the owner balance in the Vault, through a withdraw call.
     * @param _owner Address to check `maxWithdraw` for
     * @return uint256 Amount of the underlying asset that can be withdrawn
     */
    function _maxWithdraw(address _owner) internal view returns (uint256) {
        return _convertToAssets(_balanceOf(_owner), _totalSupply(), _totalAssets(), Math.Rounding.Down);
    }

    /**
     * @notice Returns the maximum amount of Vault shares that can be redeemed
     * from the owner balance in the Vault, through a redeem call.
     * @param _owner Address to check `maxRedeem` for
     * @return uint256 Amount of Vault shares that can be redeemed
     */
    function _maxRedeem(address _owner) internal view returns (uint256) {
        return _balanceOf(_owner);
    }
    /* ============ Redeem Function ============ */

    /**
     * @notice Redeem/Withdraw common flow
     * @dev When the Vault is collateralized, shares are backed by assets 1:1, `withdraw` is used.
     *      When the Vault is undercollateralized, shares are not backed by assets 1:1.
     *      `redeem` is used to avoid burning too many YieldVault shares in exchange of assets.
     * @param _caller Address of the caller
     * @param _receiver Address of the receiver of the assets
     * @param _owner Owner of the shares
     * @param _shares Shares to burn
     * @param _assets Assets to withdraw
     * @param _vaultCollateralized Whether the Vault is collateralized or not
     */
    function _redeem(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _shares,
        uint256 _assets,
        bool _vaultCollateralized
    ) internal returns (uint256) {
        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, _shares);
        }

        uint256 _yieldVaultShares;

        if (!_vaultCollateralized) {
            _yieldVaultShares = _shares.mulDiv(_yieldVault.maxRedeem(address(this)), _totalSupply(), Math.Rounding.Down);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(_owner, _shares);

        // If the Vault is collateralized, users can withdraw their deposit 1:1
        if (_vaultCollateralized) {
            _yieldVault.withdraw(_assets, _receiver, address(this));
        } else {
            // Otherwise, redeem is used to avoid burning too many YieldVault shares
            _assets = _yieldVault.redeem(_yieldVaultShares, _receiver, address(this));
        }

        if (_assets == 0) revert WithdrawZeroAssets();

        emit Withdraw(_caller, _receiver, _owner, _assets, _shares);

        return _assets;
    }

    /* ============ State Functions ============ */

    /**
     * @notice Creates `_shares` tokens and assigns them to `_receiver`, increasing the total supply.
     * @dev Emits a {Transfer} event with `from` set to the zero address.
     * @dev `_receiver` cannot be the zero address.
     * @param _receiver Address that will receive the minted shares
     * @param _shares Shares to mint
     */
    function _mint(address _receiver, uint256 _shares) internal virtual override {
        _twabController.mint(_receiver, SafeCast.toUint96(_shares));
        emit Transfer(address(0), _receiver, _shares);
    }

    /**
     * @notice Destroys `_shares` tokens from `_owner`, reducing the total supply.
     * @dev Emits a {Transfer} event with `to` set to the zero address.
     * @dev `_owner` cannot be the zero address.
     * @dev `_owner` must have at least `_shares` tokens.
     * @param _owner The owner of the shares
     * @param _shares The shares to burn
     */
    function _burn(address _owner, uint256 _shares) internal virtual override {
        _twabController.burn(_owner, SafeCast.toUint96(_shares));
        emit Transfer(_owner, address(0), _shares);
    }

    /**
     * @notice Updates `_from` and `_to` TWAB balance for a transfer.
     * @dev `_from` cannot be the zero address.
     * @dev `_to` cannot be the zero address.
     * @dev `_from` must have a balance of at least `_shares`.
     * @param _from Address to transfer from
     * @param _to Address to transfer to
     * @param _shares Shares to transfer
     */
    function _transfer(address _from, address _to, uint256 _shares) internal virtual override {
        _twabController.transfer(_from, _to, SafeCast.toUint96(_shares));
        emit Transfer(_from, _to, _shares);
    }
    /* ============ Conversion Functions ============ */

    /**
     * @notice Convert assets to shares.
     * @param _assets Amount of assets to convert
     * @param _depositedAssets Assets deposited into the YieldVault
     * @param _withdrawableAssets Assets withdrawable from the YieldVault
     * @param _rounding Rounding mode (i.e. down or up)
     * @return uint256 Amount of shares corresponding to the assets
     */
    function _convertToShares(
        uint256 _assets,
        uint256 _depositedAssets,
        uint256 _withdrawableAssets,
        Math.Rounding _rounding
    ) internal pure returns (uint256) {
        if (_assets == 0 || _depositedAssets == 0) {
            return _assets;
        }

        uint256 _collateralAssets = _collateral(_depositedAssets, _withdrawableAssets);

        return _collateralAssets == 0 ? 0 : _assets.mulDiv(_depositedAssets, _collateralAssets, _rounding);
    }

    /**
     * @notice Convert shares to assets.
     * @param _shares Amount of shares to convert
     * @param _depositedAssets Assets deposited into the YieldVault
     * @param _withdrawableAssets Assets withdrawable from the YieldVault
     * @param _rounding Rounding mode (i.e. down or up)
     * @return uint256 Amount of assets corresponding to the shares
     */
    function _convertToAssets(
        uint256 _shares,
        uint256 _depositedAssets,
        uint256 _withdrawableAssets,
        Math.Rounding _rounding
    ) internal pure returns (uint256) {
        if (_shares == 0 || _depositedAssets == 0) {
            return _shares;
        }

        uint256 _collateralAssets = _collateral(_depositedAssets, _withdrawableAssets);

        return _collateralAssets == 0 ? 0 : _shares.mulDiv(_collateralAssets, _depositedAssets, _rounding);
    }

    /**
     * @notice Returns the quantity of withdrawable underlying assets held as collateral by the YieldVault.
     * @dev When the Vault is collateralized, Vault shares are minted at a 1:1 ratio based on the user's deposited underlying assets.
     *      The total supply of shares corresponds directly to the total amount of underlying assets deposited into the YieldVault.
     *      Users have the ability to withdraw only the quantity of underlying assets they initially deposited,
     *      without access to any of the accumulated yield within the YieldVault.
     * @dev In case of undercollateralization, any remaining collateral within the YieldVault can be withdrawn.
     *      Withdrawals can be made by users for their corresponding deposit shares.
     * @param _depositedAssets Assets deposited into the YieldVault
     * @param _withdrawableAssets Assets withdrawable from the YieldVault
     * @return uint256 Available collateral
     */
    function _collateral(uint256 _depositedAssets, uint256 _withdrawableAssets) internal pure returns (uint256) {
        // If the Vault is collateralized, users can only withdraw the amount of underlying assets they deposited.
        if (_isVaultCollateralized(_depositedAssets, _withdrawableAssets)) {
            return _depositedAssets;
        }

        // Otherwise, any remaining collateral within the YieldVault is available
        // and distributed proportionally among depositors.
        return _withdrawableAssets;
    }

    /**
     * @notice Check if the Vault is collateralized.
     * @dev The vault is collateralized if the total amount of underlying assets currently held by the YieldVault
     *      is greater than or equal to the total supply of shares minted by the Vault.
     * @param _depositedAssets Assets deposited into the YieldVault
     * @param _withdrawableAssets Assets withdrawable from the YieldVault
     * @return bool True if the vault is collateralized, false otherwise
     */
    function _isVaultCollateralized(uint256 _depositedAssets, uint256 _withdrawableAssets)
        internal
        pure
        returns (bool)
    {
        return _withdrawableAssets >= _depositedAssets;
    }
}
