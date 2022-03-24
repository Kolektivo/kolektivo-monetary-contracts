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
        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        oracle.setIsValid(true);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        oracle.setMinimumProviders(1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        oracle.purgeReportsFrom(p1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        oracle.addProvider(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        oracle.removeProvider(p1);
    }

    function testSetIsValid(bool to) public {
        if (to == oracle.isValid()) {
            // Do not expect an event because state did not change.
            oracle.setIsValid(to);
        } else {
            if (to) {
                // Expect event emission.
                vm.expectEmit(true, true, true, true);
                emit OracleMarkedAsValid();

                oracle.setIsValid(to);
            } else {
                // Expect event emission.
                vm.expectEmit(true, true, true, true);
                emit OracleMarkedAsInvalid();

                oracle.setIsValid(to);
            }
        }

        assertTrue(oracle.isValid() == to);
    }

    function testSetMinimumProviders(uint to) public {
        uint before = oracle.minimumProviders();

        if (to == 0) {
            // Fails due to minimum providers of zero not allowed.
            vm.expectRevert(bytes(""));
            oracle.setMinimumProviders(to);
        } else {
            // Only expect an event if state changed.
            if (before != to) {
                vm.expectEmit(true, true, true, true);
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
        vm.expectEmit(true, true, true, true);
        emit ProviderReportsPurged(address(this), p1);

        // Purge reports from provider.
        oracle.purgeReportsFrom(p1);

        // Expect oracle data to be invalid.
        (data, valid) = oracle.getData();
        assertEq(data, 0);
        assertTrue(!valid);
    }

    function testPurgeReportsFromInvalidProvider() public {
        vm.expectRevert(Errors.InvalidProvider(address(0)));
        oracle.purgeReportsFrom(address(0));
    }

    function testAddProvider() public {
        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ProviderAdded(p1);

        oracle.addProvider(p1);

        // Function should be idempotent.
        oracle.addProvider(p1);

        // Check that p1 is eligible to push reports.
        vm.prank(p1);
        oracle.pushReport(1);
    }

    function testRemoveProvider() public {
        setUpProviders();

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ProviderRemoved(p1);

        oracle.removeProvider(p1);

        // Function should be idempotent.
        oracle.removeProvider(p1);

        // Provider should not be able to push any new reports.
        vm.prank(p1);

        vm.expectRevert(Errors.InvalidProvider(p1));
        oracle.pushReport(1);
    }

}
