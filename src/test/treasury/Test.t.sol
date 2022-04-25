// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "../../Treasury.sol";

/**
 * Errors library for Treasury's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner
        = abi.encodeWithSignature("OnlyCallableByOwner()");

    function AssetIsNotBondable(address asset)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "AssetIsNotBondable(address)",
            asset
        );
    }

    function AssetIsNotUnbondable(address asset)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "AssetIsNotUnbondable(address)",
            asset
        );
    }

    function AssetIsNotSupported(address asset)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "AssetIsNotSupported(address)",
            asset
        );
    }

    function StalePriceDeliveredByOracle(address asset, address oracle)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "StalePriceDeliveredByOracle(address,address)",
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
abstract contract TreasuryTest is DSTest {
    Vm internal constant vm = Vm(HEVM_ADDRESS);

    // SuT.
    Treasury treasury;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event AssetMarkedAsSupported(address indexed asset,
                                 address indexed oracle);
    event AssetMarkedAsUnsupported(address indexed asset);
    event AssetOracleUpdated(address indexed asset,
                             address indexed oldOracle,
                             address indexed newOracle);
    event AssetMarkedAsSupportedForBonding(address indexed asset);
    event AssetMarkedAsSupportedForUnbonding(address indexed asset);
    event AssetMarkedAsUnsupportedForBonding(address indexed asset);
    event AssetMarkedAsUnsupportedForUnbonding(address indexed asset);
    event AssetsBonded(address indexed who,
                       address indexed asset,
                       uint kttsMinted);
    event AssetsUnbonded(address indexed who,
                         address indexed asset,
                         uint kttsBurned);

    // Constants copied from elastic-receipt-token.
    // For more info see elastic-receipt-token.
    uint internal constant MAX_SUPPLY = 1_000_000_000e18;

    function setUp() public {
        treasury = new Treasury();
    }

}
