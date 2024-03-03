// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {TwabController, SPONSORSHIP_ADDRESS} from "pt-v5-twab-controller/TwabController.sol";
import {VaultHooks} from "pt-v5-vault/interfaces/IVaultHooks.sol";

interface IVault is IERC4626 {
    /* ============ Events ============ */

    /**
     * @notice Emitted when a new Vault has been deployed.
     * @param asset Address of the underlying asset used by the vault
     * @param name Name of the ERC20 share minted by the vault
     * @param symbol Symbol of the ERC20 share minted by the vault
     * @param twabController Address of the TwabController used to keep track of balances
     * @param yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
     * @param claimer Address of the claimer
     * @param yieldFeeRecipient Address of the yield fee recipient
     * @param yieldFeePercentage Yield fee percentage in integer format with 1e9 precision (50% would be 5e8)
     * @param owner Address of the contract owner
     */
    event NewVault(
        IERC20 indexed asset,
        string name,
        string symbol,
        TwabController twabController,
        IERC4626 indexed yieldVault,
        address claimer,
        address yieldFeeRecipient,
        uint256 yieldFeePercentage,
        address owner
    );

    /**
     * @notice Emitted when an account sets new hooks
     * @param account The account whose hooks are being configured
     * @param hooks The hooks being set
     */
    event SetHooks(address indexed account, VaultHooks indexed hooks);

    /**
     * @notice Emitted when yield fee is minted to the yield recipient.
     * @param caller Address that called the function
     * @param recipient Address receiving the Vault shares
     * @param shares Amount of shares minted to `recipient`
     */
    event MintYieldFee(address indexed caller, address indexed recipient, uint256 shares);

    /**
     * @notice Emitted when a new yield fee recipient has been set.
     * @param yieldFeeRecipient Address of the new yield fee recipient
     */
    event YieldFeeRecipientSet(address indexed yieldFeeRecipient);

    /**
     * @notice Emitted when a new yield fee percentage has been set.
     * @param yieldFeePercentage New yield fee percentage
     */
    event YieldFeePercentageSet(uint256 yieldFeePercentage);

    /**
     * @notice Emitted when a user sponsors the Vault.
     * @param caller Address that called the function
     * @param assets Amount of assets deposited into the Vault
     * @param shares Amount of shares minted to the caller address
     */
    event Sponsor(address indexed caller, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when a user sweeps assets held by the Vault into the YieldVault.
     * @param caller Address that called the function
     * @param assets Amount of assets sweeped into the YieldVault
     */
    event Sweep(address indexed caller, uint256 assets);

    /**
     * @notice Emitted when a user sweeps assets held by the Vault into the YieldVault.
     * @param drawId The draw id
     * @param recipient The recipient of the prize
     * @param amount The amount of the prize
     */
    event PrizeDistributed(uint24 indexed drawId, address recipient, uint256 amount);

    event DrawFinalized(uint24 indexed drawId, uint8[] winningTeams);

    event DistributionSet(uint24 indexed drawId, bytes32 merkleRoot);

    /* ============ Errors ============ */

    /// @notice Emitted when the Yield Vault is set to the zero address.
    error YieldVaultZeroAddress();

    /// @notice Emitted when the Prize Pool is set to the zero address.
    error PrizePoolZeroAddress();

    /// @notice Emitted when the Owner is set to the zero address.
    error OwnerZeroAddress();

    /**
     * @notice Emitted when the underlying asset passed to the constructor is different from the YieldVault one.
     * @param asset Address of the underlying asset passed to the constructor
     * @param yieldVaultAsset Address of the YieldVault underlying asset
     */
    error UnderlyingAssetMismatch(address asset, address yieldVaultAsset);

    /**
     * @notice Emitted when the amount being deposited for the receiver is greater than the max amount allowed.
     * @param receiver The receiver of the deposit
     * @param amount The amount to deposit
     * @param max The max deposit amount allowed
     */
    error DepositMoreThanMax(address receiver, uint256 amount, uint256 max);

    /**
     * @notice Emitted when the amount being minted for the receiver is greater than the max amount allowed.
     * @param receiver The receiver of the mint
     * @param amount The amount to mint
     * @param max The max mint amount allowed
     */
    error MintMoreThanMax(address receiver, uint256 amount, uint256 max);

    /**
     * @notice Emitted when the amount being withdrawn for the owner is greater than the max amount allowed.
     * @param owner The owner of the assets
     * @param amount The amount to withdraw
     * @param max The max withdrawable amount
     */
    error WithdrawMoreThanMax(address owner, uint256 amount, uint256 max);

    /**
     * @notice Emitted when the amount being redeemed for owner is greater than the max allowed amount.
     * @param owner The owner of the assets
     * @param amount The amount to redeem
     * @param max The max redeemable amount
     */
    error RedeemMoreThanMax(address owner, uint256 amount, uint256 max);

    /// @notice Emitted when `_deposit` is called but no shares are minted back to the receiver.
    error MintZeroShares();

    /// @notice Emitted when `_withdraw` is called but no assets are being withdrawn.
    error WithdrawZeroAssets();

    /**
     * @notice Emitted when `_withdraw` is called but the amount of assets withdrawn from the YieldVault
     *         is lower than the amount of assets requested by the caller.
     * @param requestedAssets The amount of assets requested
     * @param withdrawnAssets The amount of assets withdrawn from the YieldVault
     */
    error WithdrawAssetsLTRequested(uint256 requestedAssets, uint256 withdrawnAssets);

    /// @notice Emitted when `sweep` is called but no underlying assets are currently held by the Vault.
    error SweepZeroAssets();

    /**
     * @notice Emitted during the liquidation process when the caller is not the liquidation pair contract.
     * @param caller The caller address
     * @param liquidationPair The LP address
     */
    error CallerNotLP(address caller, address liquidationPair);

    /**
     * @notice Emitted during the liquidation process when the token in is not the prize token.
     * @param tokenIn The provided tokenIn address
     * @param prizeToken The prize token address
     */
    error LiquidationTokenInNotPrizeToken(address tokenIn, address prizeToken);

    /**
     * @notice Emitted during the liquidation process when the token out is not the vault share token.
     * @param tokenOut The provided tokenOut address
     * @param vaultShare The vault share token address
     */
    error LiquidationTokenOutNotVaultShare(address tokenOut, address vaultShare);

    /// @notice Emitted during the liquidation process when the liquidation amount out is zero.
    error LiquidationAmountOutZero();

    /**
     * @notice Emitted during the liquidation process if the amount out is greater than the available yield.
     * @param amountOut The amount out
     * @param availableYield The available yield
     */
    error LiquidationAmountOutGTYield(uint256 amountOut, uint256 availableYield);

    /// @notice Emitted when the Vault is under-collateralized.
    error VaultUndercollateralized();

    /**
     * @notice Emitted when the target token is not supported for a given token address.
     * @param token The unsupported token address
     */
    error TargetTokenNotSupported(address token);

    /// @notice Emitted when the Claimer is set to the zero address.
    error ClaimerZeroAddress();

    /**
     * @notice Emitted when the caller is not the prize claimer.
     * @param caller The caller address
     * @param claimer The claimer address
     */
    error CallerNotClaimer(address caller, address claimer);

    /**
     * @notice Emitted when the minted yield exceeds the yield fee shares available.
     * @param shares The amount of yield shares to mint
     * @param yieldFeeShares The accrued yield fee shares available
     */
    error YieldFeeGTAvailableShares(uint256 shares, uint256 yieldFeeShares);

    /**
     * @notice Emitted when the minted yield exceeds the amount of available yield in the YieldVault.
     * @param shares The amount of yield shares to mint
     * @param availableYield The amount of yield available
     */
    error YieldFeeGTAvailableYield(uint256 shares, uint256 availableYield);

    /// @notice Emitted when the Liquidation Pair being set is the zero address.
    error LPZeroAddress();

    /**
     * @notice Emitted when the yield fee percentage being set is greater than or equal to 1.
     * @param yieldFeePercentage The yield fee percentage in integer format
     * @param maxYieldFeePercentage The max yield fee percentage in integer format (this value is equal to 1 in decimal format)
     */
    error YieldFeePercentageGtePrecision(uint256 yieldFeePercentage, uint256 maxYieldFeePercentage);

    /**
     * @notice Emitted when the BeforeClaim prize hook fails
     * @param reason The revert reason that was thrown
     */
    error BeforeClaimPrizeFailed(bytes reason);

    /**
     * @notice Emitted when the AfterClaim prize hook fails
     * @param reason The revert reason that was thrown
     */
    error AfterClaimPrizeFailed(bytes reason);

    /// @notice Emitted when a prize is claimed for the zero address.
    error ClaimRecipientZeroAddress();

    /**
     * @notice Emitted when the caller of a permit function is not the owner of the assets being permitted.
     * @param caller The address of the caller
     * @param owner The address of the owner
     */
    error PermitCallerNotOwner(address caller, address owner);

    /**
     * @notice Emitted when a permit call on the underlying asset failed to set the spending allowance.
     * @dev This is likely thrown when the underlying asset does not support permit, but has a fallback function.
     * @param owner The owner of the assets
     * @param spender The spender of the assets
     * @param amount The amount of assets permitted
     * @param allowance The allowance after the permit was called
     */
    error PermitAllowanceNotSet(address owner, address spender, uint256 amount, uint256 allowance);

    error InvalidDrawPeriod(uint256 timestamp, uint256 drawPeriod);

    error AlreadyFinalized();

    error WinningTeamNotFound();

    error InvalidRecipient(address recipient);

    error InvalidAmount();

    error DistributionNotSet(uint24 drawId);
}
