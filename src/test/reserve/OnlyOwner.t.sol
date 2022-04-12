// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev onlyOwner Function Tests.
 */
contract ReserveOnlyOwner is ReserveTest {


    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != reserve.owner());

        vm.startPrank(caller);

        //----------------------------------
        // Price Floor/Ceiling Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setPriceFloor(0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setPriceCeiling(0);

        //----------------------------------
        // Debt Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setMinBackingInBPS(DEFAULT_MIN_BACKING);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.incurDebt(1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.payDebt(1);

        //----------------------------------
        // Whitelist Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.addToWhitelist(address(0));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.removeFromWhitelist(address(0));

        //----------------------------------
        // Discount Zapper Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setDiscountZapper(address(0));
    }

    //----------------------------------
    // Price Floor/Ceiling Management

    function testSetPriceFloorAndCeiling(uint floor, uint ceiling) public {
        vm.assume(floor <= ceiling);
        vm.assume(floor != 0 && ceiling != 0);

        // Set price ceiling first.
        vm.expectEmit(true, true, true, true);
        emit PriceCeilingChanged(0, ceiling);

        reserve.setPriceCeiling(ceiling);

        // Afterwards the price floor.
        vm.expectEmit(true, true, true, true);
        emit PriceFloorChanged(0, floor);

        reserve.setPriceFloor(floor);
    }

    //----------------------------------
    // Debt Management

    function testSetMinBackingInBPS(uint to) public {
        uint before = reserve.minBackingInBPS();

        if (to < MIN_BACKING_IN_BPS) {
            try reserve.setMinBackingInBPS(to) {
                revert();
            } catch {
                // Fails due to being smaller than MIN_BACKING_IN_BPS.
            }
        } else {
            // Only expect an event if state changed.
            if (before != to)   {
                vm.expectEmit(true, true, true, true);
                emit MinBackingInBPSChanged(before, to);
            }

            reserve.setMinBackingInBPS(to);

            assertEq(reserve.minBackingInBPS(), to);
        }
    }

    // @todo Move to own test file, DebtManagemet.
    function testIncurDebt() public {
        // Note that 75e16 = 0.75e18 = 0.75$.

        // Deposit some KTTs so that reserve is unequal to zero.
        reserve.addToWhitelist(address(1));
        ktt.mint(address(1), 75e16);
        vm.startPrank(address(1));
        {
            ktt.approve(address(reserve), 75e16);
            reserve.deposit(75e16);
        }
        vm.stopPrank();

        // max debt amount is 25e16 because 75% is debt limit and 75e16 is
        // in the reserve.
        reserve.incurDebt(25e16);

        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, 75e16);
        assertEq(supply, 1e18);
        assertEq(backingInBPS, DEFAULT_MIN_BACKING);
    }

    function testFailIncureDebtWithNoReserve() public {
        // Fails due to reserve being zero.
        reserve.incurDebt(1);
    }

    // @todo Test is on fail because expectRevert is not working.
    function testFailIncurDebtMoreThanAllowed() public {
        // Note that 75e16 = 0.75e18 = 0.75$.

        // Deposit some KTTs so that reserve is unequal to zero.
        reserve.addToWhitelist(address(1));
        ktt.mint(address(1), 75e16);
        vm.startPrank(address(1));
        {
            ktt.approve(address(reserve), 75e16);
            reserve.deposit(75e16);
        }
        vm.stopPrank();

        // max debt amount is 25e16 because 75% is debt limit and 75e16 is
        // in the reserve.
        uint expectedBacking = 7_500 - 1; // 0.75% - 1 bps.
        vm.expectRevert(
            Errors.SupplyExceedsReserveLimit(
                expectedBacking,
                MIN_BACKING_IN_BPS
            )
        );
        reserve.incurDebt(25e16 + 1);
    }

    function testPayDebt() public {
        emit log_string("Not Implemented");
    }

    //----------------------------------
    // Whitelist Management

    function testAddToWhitelist(address who) public {
        reserve.addToWhitelist(who);
        // Function should be idempotent.
        reserve.addToWhitelist(who);

        assertTrue(reserve.whitelist(who));
    }

    function testRemoveFromWhitelist(address who) public {
        reserve.addToWhitelist(who);

        reserve.removeFromWhitelist(who);
        // Function should be idempotent.
        reserve.removeFromWhitelist(who);

        assertTrue(!reserve.whitelist(who));
    }

    //----------------------------------
    // Discount Zapper Management

    function testSetDiscountZapper(address to) public {
        // Expect event if discount Zapper changes.
        if (to != reserve.discountZapper()) {
            vm.expectEmit(true, true, true, true);
            emit DiscountZapperChanged(reserve.discountZapper(), to);
        }

        reserve.setDiscountZapper(to);

        assertEq(reserve.discountZapper(), to);
    }

}
