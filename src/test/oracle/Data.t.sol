// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Data Tests.
 */
contract OracleData is OracleTest {

    function testDataInvalidIfOracleMarkedAsInvalid() public {
        setUpProviders();

        // Push one report so that minimumProviders is reached.
        pushValidReport(p1, 10);

        // Mark oracle as invalid.
        oracle.setIsValid(false);

        // Expect oracle data to be invalid.
        uint result;
        bool valid;
        (result, valid) = oracle.getData();
        assertEq(result, 0);
        assertTrue(!valid);
    }

    function testDataInvalidIfNotEnoughProviderReports() public {
        setUpProviders();

        // Set minimum providers to 2 but only send one report.
        oracle.setMinimumProviders(2);
        pushValidReport(p1, 10);

        // There are 2 report slots per provider. All 3 providers did not
        // push 2 reports that are considered valid.
        // Therefore, expect an event about missing reports for each provider.
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p1);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p2);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p3);

        // Expect oracle data to be invalid.
        uint result;
        bool valid;
        (result, valid) = oracle.getData();
        assertEq(result, 0);
        assertTrue(!valid);
    }

    function testDataIsAverageOfSameProviderReports(
        uint payload1,
        uint payload2
    ) public {
        setUpProviders();

        // Push two valid reports from same provider.
        pushValidReport(p1, payload1);
        pushValidReport(p1, payload2);

        // The payloads should not overlow. Otherwise the average can not be
        // calculated.
        // Note that we DO NOT check for this in the oracle contract as backend
        // monitoring should be able to detect this and purge the provider's
        // reports.
        unchecked {
            if (payload1 + payload2 < payload1) {
                return;
            }
        }

        // There are 2 report slots per provider. 2 of the 3 providers did not
        // push 2 reports that are considered valid.
        // Therefore, expect an event about missing reports for the 2 providers.
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p2);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p3);

        // Expect oracle data to be the average to the two report payloads.
        uint result;
        bool valid;
        (result, valid) = oracle.getData();
        assertEq(result, (payload1 + payload2) / 2);
        assertTrue(valid);
    }

    function testDataDoesNotIncludeTooOldReports() public {
        setUpProviders();

        // Push first valid report.
        pushValidReport(p1, 10);

        // Push second valid report.
        pushValidReport(p1, 20);

        // Now 60 minutes passed since first report was pushed.
        // It becomes invalid after reportExpirationTime seconds.
        EVM.warp(block.timestamp + reportExpirationTime - 60 minutes + 1 seconds);

        // There are 2 report slots per provider. All 3 providers did not
        // push 2 reports that are considered valid.
        // Therefore, expect an event about missing reports for each provider.
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p1);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p2);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p3);

        // Expect oracle data to only take the second report into account.
        uint result;
        bool valid;
        (result, valid) = oracle.getData();
        assertEq(result, 20);
        assertTrue(valid);
    }

    function testDataDoesNotIncludeTooRecentReports() public {
        setUpProviders();

        pushValidReport(p1, 10);

        // Push second report but wait less than reportDelay seconds so
        // that the report is not yet valid.
        EVM.prank(p1);
        oracle.pushReport(20);
        EVM.warp(block.timestamp + reportDelay - 1 seconds);

        // There are 2 report slots per provider. All 3 providers did not
        // push 2 reports that are considered valid.
        // Therefore, expect an event about missing reports for each provider.
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p1);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p2);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p3);

        // Expect oracle data to only take the first report into account.
        uint result;
        bool valid;
        (result, valid) = oracle.getData();
        assertEq(result, 10);
        assertTrue(valid);
    }

    function testDataIsMedianForEvenDifferentProviderReports() public {
        setUpProviders();

        pushValidReport(p1, 10);
        pushValidReport(p2, 20);

        // There are 2 report slots per provider. All 3 providers did not
        // push 2 reports that are considered valid.
        // Therefore, expect an event about missing reports for each provider.
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p1);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p2);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p3);

        // Expect oracle data to take the median of the two reports.
        uint result;
        bool valid;
        (result, valid) = oracle.getData();

        // Median(10, 20) = 15.
        assertEq(result, 15);
        assertTrue(valid);
    }

    function testDataIsMedianForOddDifferentProviderReports() public {
        setUpProviders();

        pushValidReport(p1, 10);
        pushValidReport(p2, 20);
        pushValidReport(p3, 30);

        // There are 2 report slots per provider. All 3 providers did not
        // push 2 reports that are considered valid.
        // Therefore, expect an event about missing reports for each provider.
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p1);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p2);
        EVM.expectEmit(true, true, true, true);
        emit ReportTimestampOutOfRange(p3);

        // Expect oracle data to take the median of the three reports.
        uint result;
        bool valid;
        (result, valid) = oracle.getData();

        // Median(10, 20, 30) = 20.
        assertEq(result, 20);
        assertTrue(valid);
    }

}
