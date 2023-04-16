// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Deployment Tests.
 */
contract OracleDeployment is OracleTest {
    function testInvariants() public {
        assertEq(oracle.owner(), address(this));
        assertEq(oracle.providersSize(), 0);
        assertTrue(oracle.isValid());
    }

    function testConstructor() public {
        assertEq(oracle.reportExpirationTime(), reportExpirationTime);
        assertEq(oracle.reportDelay(), reportDelay);
        assertEq(oracle.minimumProviders(), minimumProviders);
    }

    function testFailConstructorMinimumProvidersIsZero() public {
        // Fails due to having zero as minimum providers.
        oracle = new Oracle(
            reportExpirationTime,
            reportDelay,
            0
        );
    }

    function testFailConstructorReportExpirationTimeTooSmall() public {
        // Fails due to report expiration time being less than two times the
        // report delay.
        oracle = new Oracle(
            reportDelay * 2 - 1,
            reportDelay,
            minimumProviders
        );
    }
}
