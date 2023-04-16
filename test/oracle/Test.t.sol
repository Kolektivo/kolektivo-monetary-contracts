// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/Oracle.sol";

/**
 * Errors library for Oracle's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner = abi.encodeWithSignature("OnlyCallableByOwner()");

    function InvalidProvider(address who) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("Oracle__InvalidProvider(address)", who);
    }

    bytes internal constant NewReportTooSoonAfterPastReport =
        abi.encodeWithSignature("Oracle__NewReportTooSoonAfterPastReport()");
}

/**
 * @dev Root contract for Oracle Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
abstract contract OracleTest is Test {
    // SuT.
    Oracle oracle;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event ProviderReportPushed(address indexed provider, uint256 payload, uint256 timestamp);
    event ProviderReportsPurged(address indexed purger, address indexed provider);
    event ProviderAdded(address indexed provider);
    event ProviderRemoved(address indexed provider);
    event MinimumProvidersChanged(uint256 oldMinimumProviders, uint256 newMinimumProviders);
    event OracleMarkedAsInvalid();
    event OracleMarkedAsValid();

    // Initial settings.
    uint256 internal reportExpirationTime = 120 minutes;
    uint256 internal reportDelay = 30 minutes;
    uint256 internal minimumProviders = 1;

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
        vm.warp(1 days);
    }

    function setUpProviders() public {
        oracle.addProvider(p1);
        oracle.addProvider(p2);
        oracle.addProvider(p3);
    }

    function pushValidReport(address provider, uint256 payload) public {
        vm.prank(provider);
        oracle.pushReport(payload);

        // Wait reportDelay seconds so that report gets valid.
        vm.warp(block.timestamp + reportDelay);
    }
}
