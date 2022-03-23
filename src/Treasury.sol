// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "solrocket/Ownable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

import {
    ElasticReceiptToken
} from "elastic-receipt-token/ElasticReceiptToken.sol";

import {IERC20Metadata} from "./interfaces/_external/IERC20Metadata.sol";

interface IOracle {
    // Note that the price is returned with 18 decimal precision.
    function getData() external returns (uint, bool);
}

contract Treasury is ElasticReceiptToken, Ownable, Whitelisted {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Function is only callable for bondable assets.
    /// @param asset The address of the asset.
    error AssetIsNotBondable(address asset);

    /// @notice Function is only callable for unbondable assets.
    /// @param asset The address of the asset.
    error AssetIsNotUnbondable(address asset);

    /// @notice Function is only callable for supported assets.
    /// @param asset The address of the asset.
    error AssetIsNotSupported(address asset);

    /// @notice Functionality is limited due to stale price delivered by oracle.
    /// @param asset The address of the asset.
    /// @param oracle The address of the asset's oracle.
    error StalePriceDeliveredByOracle(address asset,
                                      address oracle);

    //--------------------------------------------------------------------------
    // Events

    //----------------------------------
    // onlyOwner Events

    //--------------
    // Asset and Oracle Management

    /// @notice Event emitted when an asset is marked as supported.
    /// @param asset The address of the asset.
    /// @param oracle The address of the asset's oracle.
    event AssetMarkedAsSupported(address indexed asset,
                                 address indexed oracle);

    /// @notice Event emitted when an asset is marked as unsupported.
    /// @param asset The address of the asset.
    event AssetMarkedAsUnsupported(address indexed asset);

    /// @notice Event emitted when an asset's oracle is updated.
    /// @param asset The address of the asset.
    /// @param oldOracle The address of the asset's old oracle.
    /// @param newOracle The address of the asset's new oracle.
    event AssetOracleUpdated(address indexed asset,
                             address indexed oldOracle,
                             address indexed newOracle);

    //--------------
    // Un/Bonding Management

    /// @notice Event emitted when an asset is marked as supported for bonding
    ///         operations.
    /// @param asset The address of the asset.
    event AssetMarkedAsSupportedForBonding(address indexed asset);

    /// @notice Event emitted when an asset is marked as supported for unbonding
    ///         operations.
    /// @param asset The address of the asset.
    event AssetMarkedAsSupportedForUnbonding(address indexed asset);

    /// @notice Event emitted when an asset is marked as unsupported for
    ///         bonding operations.
    /// @param asset The address of the asset.
    event AssetMarkedAsUnsupportedForBonding(address indexed asset);

    /// @notice Event emitted when an asset is marked as unsupported for
    ///         unbonding operations.
    /// @param asset The address of the asset.
    event AssetMarkedAsUnsupportedForUnbonding(address indexed asset);

    //----------------------------------
    // User Events

    /// @notice Event emitted when assets are bonded by some user.
    /// @param who The address of the user.
    /// @param asset The address of the asset.
    /// @param kttsMinted The number of KTTs minted.
    event AssetsBonded(address indexed who,
                       address indexed asset,
                       uint kttsMinted);

    /// @notice Event emitted when assets are unbonded by some user.
    /// @param who The address of the user.
    /// @param asset The address of the asset.
    /// @param kttsBurned The number of KTTs burned.
    event AssetsUnbonded(address indexed who,
                         address indexed asset,
                         uint kttsBurned);

    //--------------------------------------------------------------------------
    // Modifiers

    /// @notice Modifier to guarantee function is only callable for supported
    ///         assets.
    modifier isSupported(address asset) {
        if (oraclePerAsset[asset] != address(0)) {
            _;
        } else {
            revert AssetIsNotSupported(asset);
        }
    }

    /// @notice Modifier to guarantee function is only callable for bondable
    ///         assets.
    modifier isBondable(address asset) {
        if (isSupportedForBonding[asset]) {
            _;
        } else {
            revert AssetIsNotBondable(asset);
        }
    }

    /// @notice Modifier to guarantee function is only callable for unbondable
    ///         assets.
    modifier isUnbondable(address asset) {
        if (isSupportedForUnbonding[asset]) {
            _;
        } else {
            revert AssetIsNotUnbondable(asset);
        }
    }

    //--------------------------------------------------------------------------
    // Storage

    /// @notice The assets supported by the treasury, i.e. the assets taking
    ///         into account for the treasury's valuation.
    /// @dev Each supported asset always has to have a corresponding oracle
    ///      in the oraclePerAsset mapping!
    /// @dev Changeable by owner.
    /// @dev Addresses are of type ERC20.
    address[] public supportedAssets;

    /// @notice The mapping of oracles providing the price for an asset.
    /// @dev Changeable by owner.
    /// @dev Address in supportedAssets => address of type IOracle.
    mapping(address => address) public oraclePerAsset;

    /// @notice The assets supported for bond operations.
    /// @dev Changeable by owner.
    mapping(address => bool) public isSupportedForBonding;

    /// @notice The assets supported for unbond operations.
    /// @dev Changeable by owner.
    mapping(address => bool) public isSupportedForUnbonding;

    /// @notice A mapping of supported assets to its last reported price.
    /// @dev The last reported price is used in case the latest oracle fetch
    ///      is invalid.
    mapping(address => uint) public lastPricePerAsset;

    //--------------------------------------------------------------------------
    // Constructor

    constructor()
        ElasticReceiptToken("Kolektivo Treasury Token", "KTT", uint8(18))
    {
        // NO-OP
    }

    //--------------------------------------------------------------------------
    // (Un-)Bonding Functions

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
        onlyWhitelisted
    {
        address oracle = oraclePerAsset[asset];
        // Note that this check should NOT be possible to fail.
        require(oracle != address(0));

        // Get the current price of the asset.
        uint price;
        bool valid;
        (price, valid) = _queryOracleAndUpdateLastPrice(asset, oracle);

        // Do not use a cached price for bonding.
        if (!valid) {
            revert StalePriceDeliveredByOracle(asset, oracle);
        }

        // Calculate the amount of KTT to mint.
        // Note that 1 KTT equals 1 USD worth of assets in the treasury.
        // @todo Currently only supports asset with 18 decimals.
        uint mintAmount = (amount * price) / 1e18;

        // Mint the KTTs to msg.sender and fetch the asset from msg.sender.
        super._mint(msg.sender, mintAmount);
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Notify off-chain services.
        emit AssetsBonded(msg.sender, asset, mintAmount);
    }

    /// @notice Unbonds an amount of KTTs in exchange for an amount of one
    ///         asset.
    /// @dev Only callable if address is whitelisted.
    /// @dev Only callable for unbondable assets.
    /// @param asset The asset to unbond.
    /// @param ktts The amount of KTT tokens to burn.
    function unbond(address asset, uint ktts)
        external
        // Note that if an asset is unbondable, it is also supported.
        // isSupported(asset)
        isUnbondable(asset)
        validAmount(ktts)
        onlyWhitelisted
    {
        address oracle = oraclePerAsset[asset];
        // Note that this check should NOT be possible to fail.
        require(oracle != address(0));

        // Get the current price of the asset.
        uint price;
        bool valid;
        (price, valid) = _queryOracleAndUpdateLastPrice(asset, oracle);

        // Do not use a cached price for unbonding.
        if (!valid) {
            revert StalePriceDeliveredByOracle(asset, oracle);
        }

        // Burn KTTs from msg.sender.
        // Note to update the KTT amount which could have changed due to
        // rebasing.
        ktts = super._burn(msg.sender, ktts);

        // Calculate the amount of assets to withdraw for burned amount of KTTs.
        // Note that 1 KTT equals 1 USD worth of assets in the treasury.
        // @todo Currently only supports asset with 18 decimals.
        uint withdrawable = (ktts * 1e18) / price;

        // Send the assets to msg.sender.
        ERC20(asset).safeTransfer(msg.sender, withdrawable);

        // Notify off-chain services.
        emit AssetsUnbonded(msg.sender, asset, ktts);
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @notice Returns the total valuations of assets, denominated in USD, held
    ///         in the treasury.
    /// @return The USD value of assets held in the treasury.
    function totalValuation() external returns (uint) {
        return _supplyTarget();
    }

    //--------------------------------------------------------------------------
    // ElasticReceiptToken Functions

    /// @dev Computes the total valuation of assets held in the treasury and
    ///      uses that value as KTT's supply target.
    /// @dev Has to be in same decimal precision as token, i.e. 18.
    function _supplyTarget()
        internal
        override(ElasticReceiptToken)
        returns (uint)
    {
        // Declare variables outside of loop to save gas.
        address asset;
        address oracle;
        uint assetBalance;
        uint price;
        bool valid;

        // The total valuation of assets in the treasury.
        uint total;

        uint len = supportedAssets.length;
        for (uint i; i < len; ) {
            asset = supportedAssets[i];
            assetBalance = ERC20(asset).balanceOf(address(this));

            oracle = oraclePerAsset[asset];
            (price, valid) = _queryOracleAndUpdateLastPrice(asset, oracle);

            // Continue/Break early if there is not asset balance.
            // Note to query oracle anyway to update last price.
            if (assetBalance == 0) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked { ++i; }
                    continue;
                }
            }

            if (valid) {
                // If the new price is valid, multiply the price with the
                // asset's balance and add the asset's valuation to the total
                // valuation.
                // @todo Currently only supports asset with 18 decimals.
                total += (assetBalance * price) / 1e18;
            } else {
                // If the new price is invalid, multiply the last cached price
                // with the asset's balance and add the asset's valuation to
                // the total valuation.
                price = lastPricePerAsset[asset];

                // Note that this check should NOT be possible to fail.
                require(price != 0);

                // @todo Currently only supports asset with 18 decimals.
                total += (assetBalance * price) / 1e18;
            }

            unchecked { ++i; }
        }

        // Return the total valuation of assets in the treasury.
        return total;
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Emergency Functions
    // For more info see https://github.com/byterocket/KTT-Treasury/issues/1.

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
    // Whitelist Management

    /// @notice Adds an address to the whitelist.
    /// @dev Only callable by owner.
    /// @param who The address to add to the whitelist.
    function addToWhitelist(address who) external onlyOwner {
        super._addToWhitelist(who);
    }

    /// @notice Removes an address from the whitelist.
    /// @dev Only callable by owner.
    /// @param who The address to remove from the whitelist.
    function removeFromWhitelist(address who) external onlyOwner {
        super._removeFromWhitelist(who);
    }

    //----------------------------------
    // Asset and Oracle Management

    /// @notice Adds a new asset as being supported.
    /// @dev Only callable by owner.
    /// @param asset The address of the asset.
    /// @param oracle The address of the asset's oracle.
    function supportAsset(address asset, address oracle) external onlyOwner {
        address oldOracle = oraclePerAsset[asset];

        // Do nothing if asset is already supported and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert if asset is already supported but oracles differ.
        // Note that the updateAssetOracle function should be used for this.
        require(oldOracle == address(0));

        // Check if oracle delivers valid data and, if so, update the asset's
        // last price.
        bool valid;
        (/*price*/, valid) = _queryOracleAndUpdateLastPrice(asset, oracle);

        // Do not accept invalid oracle.
        if (!valid) {
            revert StalePriceDeliveredByOracle(asset, oracle);
        }

        // Add asset and oracle to mappings.
        supportedAssets.push(asset);
        oraclePerAsset[asset] = oracle;

        // Notify off-chain services.
        emit AssetMarkedAsSupported(asset, oracle);
    }

    /// @notice Removes an asset from being supported.
    /// @dev Only callable by owner.
    /// @param asset The address of the asset.
    function unsupportAsset(address asset) external onlyOwner {
        // Do nothing if asset is already not supported.
        // Note that we do not use the isSupported modifier to be idempotent.
        if (oraclePerAsset[asset] == address(0)) {
            return;
        }

        // Remove assets' oracle.
        delete oraclePerAsset[asset];

        // Remote asset's last price.
        delete lastPricePerAsset[asset];

        // Remove asset from supportedAssets array.
        uint len = supportedAssets.length;
        for (uint i; i < len; ) {
            if (asset == supportedAssets[i]) {
                if (i < len - 1) {
                    supportedAssets[i] = supportedAssets[len - 1];
                }
                supportedAssets.pop();
            }

            unchecked { ++i; }
        }

        // Notify off-chain services.
        emit AssetMarkedAsUnsupported(asset);
    }

    /// @notice Updates the oracle for an asset.
    /// @dev Only callable by owner.
    /// @param asset The asset to update the oracle for.
    /// @param oracle The new asset's oracle.
    function updateAssetOracle(address asset, address oracle)
        external
        isSupported(asset)
        onlyOwner
    {
        // Cache old oracle.
        address oldOracle = oraclePerAsset[asset];

        // Do nothing if new oracle is same as old oracle.
        if (oldOracle == oracle) {
            return;
        }

        // Check if oracle delivers valid data and, if so, update the asset's
        // last price.
        bool valid;
        (/*price*/, valid) = _queryOracleAndUpdateLastPrice(asset, oracle);

        // Do not accept invalid oracle.
        if (!valid) {
            revert StalePriceDeliveredByOracle(asset, oracle);
        }

        // Update asset's oracle and notify off-chain services.
        oraclePerAsset[asset] = oracle;
        emit AssetOracleUpdated(asset, oldOracle, oracle);
    }

    //----------------------------------
    // Un/Bonding Management

    /// @notice Marks an asset as bondable.
    /// @dev Only callable by owner.
    /// @param asset The asset to mark as bondable.
    function supportAssetForBonding(address asset)
        external
        isSupported(asset)
        onlyOwner
    {
        // Do nothing if asset is already supported for bonding.
        if (isSupportedForBonding[asset]) {
            return;
        }

        // Mark asset as being supported for bonding and notify off-chain
        // services.
        isSupportedForBonding[asset] = true;
        emit AssetMarkedAsSupportedForBonding(asset);
    }

    /// @notice Marks an asset as non-bondable.
    /// @dev Only callable by owner.
    /// @param asset The asset to mark as non-bondable.
    function unsupportAssetForBonding(address asset)
        external
        isSupported(asset)
        onlyOwner
    {
        // Do nothing if asset is already unsupported for bonding.
        if (!isSupportedForBonding[asset]) {
            return;
        }

        // Mark asset as being unsupported for bonding and notify off-chain
        // services.
        isSupportedForBonding[asset] = false;
        emit AssetMarkedAsUnsupportedForBonding(asset);
    }

    /// @notice Marks an asset as unbondable.
    /// @dev Only callable by owner.
    /// @param asset The asset to mark as unbondable.
    function supportAssetForUnbonding(address asset)
        external
        isSupported(asset)
        onlyOwner
    {
        // Do nothing if asset is already supported for unbonding.
        if (isSupportedForUnbonding[asset]) {
            return;
        }

        // Mark asset as being supported for unbonding and notify off-chain
        // services.
        isSupportedForUnbonding[asset] = true;
        emit AssetMarkedAsSupportedForUnbonding(asset);
    }

    /// @notice Marks an asset as non-unbondable.
    /// @dev Only callable by owner.
    /// @param asset The asset to mark as non-unbondable.
    function unsupportAssetForUnbonding(address asset)
        external
        isSupported(asset)
        onlyOwner
    {
        // Do nothing if asset is already unsupported for unbonding.
        if (!isSupportedForUnbonding[asset]) {
            return;
        }

        // Mark asset as being unsupported for unbonding and notify off-chain
        // services.
        isSupportedForUnbonding[asset] = false;
        emit AssetMarkedAsUnsupportedForUnbonding(asset);
    }

    //--------------------------------------------------------------------------
    // Private Functions

    /// @dev Query's the given oracle and updates the asset's last price.
    ///      Returns the current price and true if oracle is valid, 0 and false
    ///      otherwise.
    function _queryOracleAndUpdateLastPrice(address asset, address oracle)
        private
        returns (uint, bool)
    {
        uint price;
        bool valid;
        (price, valid) = IOracle(oracle).getData();

        // Return false if oracle is invalid or price is zero.
        if (!valid || price == 0) {
            return (0, false);
        }

        // Cache current price.
        lastPricePerAsset[asset] = price;

        return (price, true);
    }

}