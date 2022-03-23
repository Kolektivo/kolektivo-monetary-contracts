// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "../../Treasury.sol";

import {HEVM} from "../utils/HEVM.sol";

/**
 * @dev Root Contract for Treasury Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
abstract contract TreasuryTest is DSTest {
    HEVM internal constant EVM = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

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
