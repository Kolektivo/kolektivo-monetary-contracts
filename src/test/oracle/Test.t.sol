// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "../../Oracle.sol";

import {HEVM} from "../utils/HEVM.sol";

/**
 * @dev Root contract for Oracle Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
abstract contract OracleTest is DSTest {
    HEVM internal constant EVM = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // SuT.
    Oracle oracle;

    // Initial settings.
    uint internal reportExpirationTime = 120 minutes;
    uint internal reportDelay = 30 minutes;
    uint internal minimumProviders = 1;

    // Provider addresses.
    address internal p1 = address(1);
    address internal p2 = address(2);
    address internal p3 = address(3);

    //--------------------------------------------------------------------------
    // Set Up Functions

    function setUp() public {
        oracle = new Oracle(
            reportExpirationTime,
            reportDelay,
            minimumProviders
        );

        // Set block.timestamp to something higher than 1.
        EVM.warp(1 days);
    }

    function setUpProviders() public {
        oracle.addProvider(p1);
        oracle.addProvider(p2);
        oracle.addProvider(p3);
    }

    function pushValidReport(address provider, uint payload) public {
        EVM.prank(provider);
        oracle.pushReport(payload);

        // Wait reportDelay seconds so that report gets valid.
        EVM.warp(block.timestamp + reportDelay);
    }

}
