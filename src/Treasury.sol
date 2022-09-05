// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

// External Interfaces.
import {IERC20Metadata} from "./interfaces/_external/IERC20Metadata.sol";
import {IERC721Receiver} from "./interfaces/_external/IERC721Receiver.sol";

// External Contracts.
import {ERC20} from "solmate/tokens/ERC20.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";

// External Libraries.
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// Internal Interfaces.
import {IOracle} from "./interfaces/IOracle.sol";

// Internal Contracts.
import {
    ElasticReceiptToken
} from "./ElasticReceiptToken.sol";

// Internal Libraries.
import {Wad} from "./lib/Wad.sol";

/**
 * @title Treasury
 *
 * @dev A treasury in which the owner can bond and redeem assets.
 *      The treasury token (KTT) is continously synced to the treasury's total
 *      value in USD of assets held. This is made possible by inheriting from
 *      the ElasticReceiptToken.
 *
 *      Naming Conventions for non-public variables:
 *      - If a variable does NOT include the term `wad` the decimal precision
 *        is either unknown or unequal to 18.
 *      - If a variable does include the term `wad` the decimal precision is
 *        18.
 *
 * @author byterocket
 */
contract Treasury is
    ElasticReceiptToken,
    TSOwnable,
    IERC721Receiver
{
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Function is only callable for bondable assets.
    /// @param asset The address of the asset.
    error Treasury__AssetIsNotBondable(address asset);

    /// @notice Function is only callable for redeemable assets.
    /// @param asset The address of the asset.
    error Treasury__AssetIsNotRedeemable(address asset);

    /// @notice Function is only callable for registered assets.
    /// @param asset The address of the asset.
    error Treasury__AssetIsNotRegistered(address asset);

    /// @notice Functionality is limited due to stale price delivered by oracle.
    /// @param asset The address of the asset.
    /// @param oracle The address of the asset's oracle.
    error Treasury__StalePriceDeliveredByOracle(address asset, address oracle);

    //--------------------------------------------------------------------------
    // Events

    //----------------------------------
    // Price Events

    /// @notice Event emitted when an asset's cached price is updated.
    /// @param asset The address of the asset.
    /// @param oracle The address of the oracle.
    /// @param oldPrice The cached price before the update.
    /// @param newPrice The cached price after the update.
    event AssetPriceUpdated(
        address indexed asset,
        address indexed oracle,
        uint oldPrice,
        uint newPrice
    );

    //----------------------------------
    // onlyOwner Events

    //--------------
    // Asset and Oracle Management

    /// @notice Event emitted when an asset is registered
    /// @param asset The address of the asset.
    /// @param oracle The address of the asset's oracle.
    event AssetRegistered(address indexed asset, address indexed oracle, AssetType assetType);

    /// @notice Event emitted when an asset is deregistered.
    /// @param asset The address of the asset.
    event AssetDeregistered(address indexed asset);

    /// @notice Event emitted when an asset's oracle is updated.
    /// @param asset The address of the asset.
    /// @param oldOracle The address of the asset's old oracle.
    /// @param newOracle The address of the asset's new oracle.
    event AssetOracleUpdated(
        address indexed asset,
        address indexed oldOracle,
        address indexed newOracle
    );

    //--------------
    // Un/Bonding Management

    /// @notice Event emitted when an asset is listed as bondable.
    /// @param asset The address of the asset.
    event AssetListedAsBondable(address indexed asset);

    /// @notice Event emitted when an asset is listed as redeemable.
    /// @param asset The address of the asset.
    event AssetListedAsRedeemable(address indexed asset);

    /// @notice Event emitted when an asset is delisted as bondable.
    /// @param asset The address of the asset.
    event AssetDelistedAsBondable(address indexed asset);

    /// @notice Event emitted when an asset is delisted as redeemable.
    /// @param asset The address of the asset.
    event AssetDelistedAsRedeemable(address indexed asset);

    //----------------------------------
    // User Events

    /// @notice Event emitted when assets are bonded.
    /// @param who The address of the user.
    /// @param asset The address of the asset.
    /// @param kttsMinted The number of KTTs minted.
    event AssetsBonded(
        address indexed who,
        address indexed asset,
        uint kttsMinted
    );

    /// @notice Event emitted when assets are redeemed.
    /// @param who The address of the user.
    /// @param asset The address of the asset.
    /// @param kttsBurned The number of KTTs burned.
    event AssetsRedeemed(
        address indexed who,
        address indexed asset,
        uint kttsBurned
    );

    //--------------------------------------------------------------------------
    // Modifiers

    /// @notice Modifier to guarantee function is only callable with registered
    ///         assets.
    modifier isRegistered(address asset) {
        if (oraclePerAsset[asset] == address(0)) {
            revert Treasury__AssetIsNotRegistered(asset);
        }
        _;
    }

    /// @notice Modifier to guarantee function is only callable with bondable
    ///         assets.
    modifier isBondable(address asset) {
        if (!isAssetBondable[asset]) {
            revert Treasury__AssetIsNotBondable(asset);
        }
        _;
    }

    /// @notice Modifier to guarantee function is only callable with redeemable
    ///         assets.
    modifier isRedeemable(address asset) {
        if (!isAssetRedeemable[asset]) {
            revert Treasury__AssetIsNotRedeemable(asset);
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Storage

    /// @notice The assets registered by the treasury, i.e. the assets taking
    ///         into account for the treasury's valuation.
    /// @dev Each registered asset always has to have a corresponding oracle
    ///      in the oraclePerAsset mapping!
    /// @dev Changeable by owner.
    /// @dev Addresses are of type ERC20.
    address[] public registeredAssets;

    /// @notice The type of each ERC20-based asset registered by the treasury
    /// @dev    Changeable by owner
    /// @dev    Address in registeredAssets => Asset Type (enum)
    mapping(address => AssetType) public typeOfAsset;

    /// @notice The mapping of oracles providing the price for an asset.
    /// @dev Changeable by owner.
    /// @dev Address in registeredAssets => address of type IOracle.
    mapping(address => address) public oraclePerAsset;

    /// @notice Mapping of bondable assets.
    /// @dev Changeable by owner.
    mapping(address => bool) public isAssetBondable;

    /// @notice Mapping of redeemable assets.
    /// @dev Changeable by owner.
    mapping(address => bool) public isAssetRedeemable;

    /// @notice Each ERC20-based asset is of a certain type, either it is a regular
    ///         token, a stable token or an ecological asset (e.g. fractionalized
    ///         GeoNFTs).
    enum AssetType {
        Default,
        Stable,
        Ecological
    }

    //--------------------------------------------------------------------------
    // Constructor

    constructor()
        ElasticReceiptToken("Kolektivo Treasury Token", "KTT", uint8(18))
    {
        // NO-OP
    }

    //--------------------------------------------------------------------------
    // Bond & Redeem Functions

    /// @notice Bonds an amount of one asset in exchange for an amount of KTTs.
    /// @dev Only callable if address is whitelisted.
    /// @dev Only callable for bondable assets.
    /// @param asset The asset to bond.
    /// @param amount The amount of assets to bond.
    function bond(address asset, uint amount)
        external
        // Note that if an asset is bondable, it is also supported.
        // isSupported(asset)
        isBondable(asset)
        validAmount(amount)
        onlyOwner
    {
        // Convert amount to wad.
        uint amountWad = Wad.convertToWad(asset, amount);

        // Calculate the amount of KTTs to mint.
        // Note that 1 KTT equals 1 USD worth of assets in the treasury.
        uint mintWad = (amountWad * _queryPrice(asset)) / 1e18;

        // Mint the KTTs to msg.sender and fetch the asset from msg.sender.
        super._mint(msg.sender, mintWad);
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Notify off-chain services.
        emit AssetsBonded(msg.sender, asset, mintWad);
    }

    /// @notice Redeems an amount of KTTs in exchange for an amount of one
    ///         asset.
    /// @dev Only callable if address is whitelisted.
    /// @dev Only callable for redeemable assets.
    /// @param asset The asset to unbond.
    /// @param kttWad The amount of KTT tokens to burn.
    function redeem(address asset, uint kttWad)
        external
        // Note that if an asset is unbondable, it is also supported.
        // isSupported(asset)
        isRedeemable(asset)
        validAmount(kttWad)
        onlyOwner
    {
        // Burn KTTs from msg.sender.
        // Note to update the KTT amount which could have changed due to
        // rebasing.
        kttWad = super._burn(msg.sender, kttWad);

        // Calculate the amount of assets to withdraw for burned amount of KTTs.
        // Note that 1 KTT equals 1 USD worth of assets in the treasury.
        uint withdrawableWad = (kttWad * 1e18) / _queryPrice(asset);

        // Adjust to decimal precision of the asset.
        uint withdrawable = Wad.convertFromWad(asset, withdrawableWad);

        // Send the assets to msg.sender.
        ERC20(asset).safeTransfer(msg.sender, withdrawable);

        // Notify off-chain services.
        emit AssetsRedeemed(msg.sender, asset, kttWad);
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @notice Returns the total valuation of assets, denominated in USD, held
    ///         in the treasury.
    /// @return The USD value of assets held in the treasury.
    function totalValuation() external view returns (uint) {
        return _supplyTarget();
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    //--------------------------------------------------------------------------
    // ElasticReceiptToken Functions

    /// @dev Computes the total valuation of assets held in the treasury and
    ///      uses that value as KTT's supply target.
    /// @dev Has to be in same decimal precision as token, i.e. 18.
    function _supplyTarget()
        internal
        view
        override(ElasticReceiptToken)
        returns (uint)
    {
        // Declare variables outside of loop to save gas.
        address asset;
        uint assetBalance;
        uint assetBalanceWad;

        // The total valuation of assets in the treasury.
        uint totalWad;

        uint len = registeredAssets.length;
        for (uint i; i < len; ) {
            asset = registeredAssets[i];
            assetBalance = ERC20(asset).balanceOf(address(this));

            // Continue/Break early if there is no asset balance.
            if (assetBalance == 0) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked { ++i; }
                    continue;
                }
            }

            // Multiply the asset's price with the asset's balance and add the
            // asset's valuation to the total valuation.
            assetBalanceWad = Wad.convertToWad(asset, assetBalance);
            totalWad += (assetBalanceWad * _queryPrice(asset)) / 1e18;

            unchecked { ++i; }
        }

        // Return the total valuation of assets in the treasury.
        return totalWad;
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Emergency Functions
    // For more info see Issue #2.

    /// @notice Executes a call on a target.
    /// @dev Only callable by owner.
    /// @param target The address to call.
    /// @param callData The call data.
    function executeTx(address target, bytes memory callData)
        external
        onlyOwner
    {
        bool success;
        (success, /*returnData*/) = target.call(callData);
        require(success);
    }

    //----------------------------------
    // Asset and Oracle Management

    /// @notice Withdraws some amount of given asset to some recipient.
    /// @dev Note that a rebase is executed after the withdrawal!
    ///      In case the asset was marked as supported, i.e. the asset's
    ///      balance valuation taken into account for the total valuation
    ///      calculation, the loss in USD valuation through the withdrawal
    ///      of the asset amount is synched to each token holder.
    ///      While this operation is non-dilutive, it could reduce the token
    ///      balance of each holder.
    /// @dev Only callable by owner.
    /// @param asset The address of the asset.
    /// @param recipient The recipient address.
    /// @param amount The amount of the asset to withdraw.
    function withdrawAsset(address asset, address recipient, uint amount)
        external
        validAmount(amount)
        validRecipient(recipient)
        onlyOwner
    {
        // @todo Add Event!
        // Make sure that asset's code is non-empty.
        // Note that solmate's safeTransferLib does not include this check.
        require(asset.code.length != 0);

        // Transfer asset amount to recipient.
        // Fails if balance not sufficient.
        ERC20(asset).safeTransfer(recipient, amount);

        // Initiate rebase.
        // Note that the possible loss in USD valuation is therefore synched to
        // each token holder.
        super.rebase();
    }

    /// @notice Registers a new asset.
    /// @dev Only callable by owner.
    /// @param asset The address of the asset.
    /// @param oracle The address of the asset's oracle.
    /// @param assetType The type of the asset
    function registerAsset(address asset, address oracle, AssetType assetType) external onlyOwner {
        // Make sure that asset's code is non-empty.
        // Note that solmate's safeTransferLib does not include this check.
        require(asset.code.length != 0);

        address oldOracle = oraclePerAsset[asset];

        // Do nothing if asset is already registered and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert if asset is already registered but oracles differ.
        // Note that the updateAssetOracle function should be used for this.
        require(oldOracle == address(0));

        // Query oracle.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Do not accept invalid oracle response or price of zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StalePriceDeliveredByOracle(asset, oracle);
        }

        // Revert if the asset type is invalid
        require(uint(assetType) <= 2);

        // Add asset and oracle to storage.
        registeredAssets.push(asset);
        oraclePerAsset[asset] = oracle;
        typeOfAsset[asset] = assetType;

        // Notify off-chain services.
        emit AssetRegistered(asset, oracle, assetType);
    }

    /// @notice Deregisters an asset.
    /// @dev Only callable by owner.
    /// @param asset The address of the asset.
    function deregisterAsset(address asset) external onlyOwner {
        // Do nothing if asset is already not supported.
        // Note that we do not use the isSupported modifier to be idempotent.
        if (oraclePerAsset[asset] == address(0)) {
            return;
        }

        // Remove asset's oracle.
        delete oraclePerAsset[asset];
        delete typeOfAsset[asset];

        // Remove asset from registeredAssets array.
        uint len = registeredAssets.length;
        for (uint i; i < len; ) {
            if (asset == registeredAssets[i]) {
                // If not last elem in array, copy last elem to this index.
                if (i < len - 1) {
                    registeredAssets[i] = registeredAssets[len - 1];
                }
                registeredAssets.pop();

                emit AssetDeregistered(asset);
                break;
            }

            unchecked { ++i; }
        }
    }

    /// @notice Updates the oracle for an asset.
    /// @dev Only callable by owner.
    /// @param asset The asset to update the oracle for.
    /// @param oracle The new asset's oracle.
    function updateAssetOracle(address asset, address oracle)
        external
        isRegistered(asset)
        onlyOwner
    {
        // Cache old oracle.
        address oldOracle = oraclePerAsset[asset];

        // Do nothing if new oracle is same as old oracle.
        if (oldOracle == oracle) {
            return;
        }

        // Query new oracle.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Do not accept invalid oracle response or price of zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StalePriceDeliveredByOracle(asset, oracle);
        }

        // Update asset's oracle and notify off-chain services.
        oraclePerAsset[asset] = oracle;
        emit AssetOracleUpdated(asset, oldOracle, oracle);
    }

    //----------------------------------
    // Un/Bonding Management

    /// @notice Lists an asset as bondable.
    /// @dev Only callable by owner.
    /// @param asset The asset to list as bondable.
    function listAssetAsBondable(address asset)
        external
        isRegistered(asset)
        onlyOwner
    {
        // Do nothing if asset is already listed as bondable.
        if (isAssetBondable[asset]) {
            return;
        }

        // Mark asset as being listed as bondable and notify off-chain
        // services.
        isAssetBondable[asset] = true;
        emit AssetListedAsBondable(asset);
    }

    /// @notice Delists an asset as bondable.
    /// @dev Only callable by owner.
    /// @param asset The asset to delist as bondable.
    function delistAssetAsBondable(address asset)
        external
        isRegistered(asset)
        onlyOwner
    {
        // Do nothing if asset is already delisted as bondable.
        if (!isAssetBondable[asset]) {
            return;
        }

        // Mark asset as being delisted as bondable and notify off-chain
        // services.
        isAssetBondable[asset] = false;
        emit AssetDelistedAsBondable(asset);
    }

    /// @notice Lists an asset as redeemable.
    /// @dev Only callable by owner.
    /// @param asset The asset to list as redeemable.
    function listAssetAsRedeemable(address asset)
        external
        isRegistered(asset)
        onlyOwner
    {
        // Do nothing if asset is already listed as redeemable.
        if (isAssetRedeemable[asset]) {
            return;
        }

        // Mark asset as being listed as redeemable and notify off-chain
        // services.
        isAssetRedeemable[asset] = true;
        emit AssetListedAsRedeemable(asset);
    }

    /// @notice Delists an asset as redeemable
    /// @dev Only callable by owner.
    /// @param asset The asset to delist as redeemable.
    function delistAssetAsRedeemable(address asset)
        external
        isRegistered(asset)
        onlyOwner
    {
        // Do nothing if asset is already delisted as redeemable.
        if (!isAssetRedeemable[asset]) {
            return;
        }

        // Mark asset as being delisted as redeemable and notify off-chain
        // services.
        isAssetRedeemable[asset] = false;
        emit AssetDelistedAsRedeemable(asset);
    }

    //--------------------------------------------------------------------------
    // Private Functions

    /// @dev Query's the price for given asset from the asset's oracle.
    ///      Reverts in case the oracle or delivered price is invalid.
    function _queryPrice(address asset) private view returns (uint) {
        address oracle = oraclePerAsset[asset];
        assert(oracle != address(0));

        // Note that price is returned in 18 decimal precision.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Revert if oracle is invalid or price is zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StalePriceDeliveredByOracle(asset, oracle);
        }

        return priceWad;
    }

}
