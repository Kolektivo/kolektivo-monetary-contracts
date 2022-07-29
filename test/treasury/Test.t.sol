// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/Treasury.sol";

/**
 * Errors library for Treasury's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner
        = abi.encodeWithSignature("OnlyCallableByOwner()");

    // Inherited from pmerkleplant/elastic-receipt-token.sol.
    bytes internal constant InvalidAmount
        = abi.encodeWithSignature("InvalidAmount()");
    bytes internal constant InvalidRecipient
        = abi.encodeWithSignature("InvalidRecipient()");

    function AssetIsNotBondable(address asset)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__AssetIsNotBondable(address)",
            asset
        );
    }

    function AssetIsNotRedeemable(address asset)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__AssetIsNotRedeemable(address)",
            asset
        );
    }

    function AssetIsNotRegistered(address asset)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__AssetIsNotRegistered(address)",
            asset
        );
    }

    function StalePriceDeliveredByOracle(address asset, address oracle)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__StalePriceDeliveredByOracle(address,address)",
            asset,
            oracle
        );
    }
}

/**
 * @dev Root Contract for Treasury Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
abstract contract TreasuryTest is Test {
    // SuT.
    Treasury treasury;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event AssetRegistered(address indexed asset, address indexed oracle);
    event AssetDeregistered(address indexed asset);
    event AssetOracleUpdated(
        address indexed asset,
        address indexed oldOracle,
        address indexed newOracle
    );
    event AssetListedAsBondable(address indexed asset);
    event AssetListedAsRedeemable(address indexed asset);
    event AssetDelistedAsBondable(address indexed asset);
    event AssetDelistedAsRedeemable(address indexed asset);
    event AssetsBonded(
        address indexed who,
        address indexed asset,
        uint kttsMinted
    );
    event AssetsRedeemed(
        address indexed who,
        address indexed asset,
        uint kttsBurned
    );

    // Constants copied from elastic-receipt-token.
    // For more info see elastic-receipt-token.
    uint internal constant MAX_SUPPLY = 1_000_000_000e18;

    function setUp() public {
        treasury = new Treasury();
    }

}
