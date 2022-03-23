// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Provider Tests.
 */
contract OracleProvider is OracleTest {

    function testPushReport(uint payload) public {
        setUpProviders();

        pushValidReport(p1, payload);

        // Expect pushed payload being delivered from oracle.
        uint data;
        bool valid;
        (data, valid) = oracle.getData();
        assertEq(data, payload);
        assertTrue(valid);
    }

    function testFailPushReportInvalidProvider(address caller) public {
        // Fails with InvalidProvider.
        EVM.prank(caller);
        oracle.pushReport(10);
    }

    function testFailPushReportTooSoon() public {
        setUpProviders();

        // Push first report.
        EVM.prank(p1);
        oracle.pushReport(10);

        // Wait less than reportDelay seconds.
        EVM.warp(block.timestamp + reportDelay - 1 seconds);

        // Fails with NewReportTooSoonAfterPastReport.
        EVM.prank(p1);
        oracle.pushReport(10);
    }

    function testPurgeReports() public {
        setUpProviders();

        pushValidReport(p1, 10);

        // Expect correct data being delivered from oracle.
        uint data;
        bool valid;
        (data, valid) = oracle.getData();
        assertEq(data, 10);
        assertTrue(valid);

        // Purge reports.
        EVM.prank(p1);
        oracle.purgeReports();

        // Expect oracle data to be invalid.
        (data, valid) = oracle.getData();
        assertEq(data, 0);
        assertTrue(!valid);
    }

    function testFailPurgeReportsInvalidProvider(address caller) public {
        // Fails with InvalidProvider.
        EVM.prank(caller);
        oracle.purgeReports();
    }

}
