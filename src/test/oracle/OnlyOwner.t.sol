// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev onlyOwner Function Tests.
 */
contract OracleOnlyOwner is OracleTest {

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        if (caller == oracle.owner()) {
            return;
        }
        EVM.startPrank(caller);

        try oracle.setIsValid(true) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try oracle.setMinimumProviders(1) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try oracle.purgeReportsFrom(p1) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try oracle.addProvider(caller) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try oracle.removeProvider(p1) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }
    }

    function testSetIsValid(bool to) public {
        if (to == oracle.isValid()) {
            // Do not expect an event because state did not change.
            oracle.setIsValid(to);
        } else {
            if (to) {
                // Expect event emission.
                EVM.expectEmit(true, true, true, true);
                emit OracleMarkedAsValid();

                oracle.setIsValid(to);
            } else {
                // Expect event emission.
                EVM.expectEmit(true, true, true, true);
                emit OracleMarkedAsInvalid();

                oracle.setIsValid(to);
            }
        }

        assertTrue(oracle.isValid() == to);
    }

    function testSetMinimumProviders(uint to) public {
        uint before = oracle.minimumProviders();

        if (to == 0) {
            try oracle.setMinimumProviders(to) {
                revert();
            } catch {
                // Fails due to minimum providers of zero not allowed.
            }
        } else {
            // Only expect an event if state changed.
            if (before != to) {
                EVM.expectEmit(true, true, true, true);
                emit MinimumProvidersChanged(before, to);
            }

            oracle.setMinimumProviders(to);

            assertEq(oracle.minimumProviders(), to);
        }
    }

    function testPurgeReportsFrom() public {
        // Setup providers and push a valid report.
        setUpProviders();
        pushValidReport(p1, 10);

        // Expect correct data being delivered from oracle.
        uint data;
        bool valid;
        (data, valid) = oracle.getData();
        assertEq(data, 10);
        assertTrue(valid);

        // Expect event emission.
        EVM.expectEmit(true, true, true, true);
        emit ProviderReportsPurged(address(this), p1);

        // Purge reports from provider.
        oracle.purgeReportsFrom(p1);

        // Expect oracle data to be invalid.
        (data, valid) = oracle.getData();
        assertEq(data, 0);
        assertTrue(!valid);
    }

    function testFailPurgeReportsFromInvalidProvider() public {
        // Fails with InvalidProvider.
        oracle.purgeReportsFrom(address(0));
    }

    function testAddProvider() public {
        // Expect event emission.
        EVM.expectEmit(true, true, true, true);
        emit ProviderAdded(p1);

        oracle.addProvider(p1);

        // Function should be idempotent.
        oracle.addProvider(p1);

        // Check that p1 is eligible to push reports.
        EVM.prank(p1);
        oracle.pushReport(1);
    }

    function testRemoveProvider() public {
        setUpProviders();

        // Expect event emission.
        EVM.expectEmit(true, true, true, true);
        emit ProviderRemoved(p1);

        oracle.removeProvider(p1);

        // Function should be idempotent.
        oracle.removeProvider(p1);

        EVM.prank(p1);
        try oracle.pushReport(1) {
            revert();
        } catch {
            // Fails due to p1 not eligible to push reports anymore.
        }
    }

}
