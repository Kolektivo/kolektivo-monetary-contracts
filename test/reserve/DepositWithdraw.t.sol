// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Deposit and Withdraw Function Tests.
 */
contract ReserveDepositWithdraw is ReserveTest {

    //--------------------------------------------------------------------------
    // User Deposits/Withdraws

    function testDeposit(address user, uint deposit) public {
        _assumeValidAddress(user);
        _assumeValidDeposit(deposit);

        reserve.addToWhitelist(user);

        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);

            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), user, deposit);

            reserve.deposit(deposit);
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), 0);
        assertEq(ktt.balanceOf(address(reserve)), deposit);

        assertEq(kol.balanceOf(user), deposit);
        assertEq(kol.totalSupply(), deposit);

        _checkBacking(deposit, deposit, BPS);
    }

    function testDepositFor(address user, address receiver, uint deposit)
        public
    {
        _assumeValidAddress(user);
        _assumeValidAddress(receiver);
        _assumeValidDeposit(deposit);

        reserve.addToWhitelist(user);

        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);

            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), receiver, deposit);

            reserve.depositFor(receiver, deposit);
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), 0);
        assertEq(ktt.balanceOf(address(reserve)), deposit);

        assertEq(kol.balanceOf(receiver), deposit);
        assertEq(kol.totalSupply(), deposit);

        _checkBacking(deposit, deposit, BPS);
    }

    function testDepositAll(address user, uint deposit) public {
        _assumeValidAddress(user);
        _assumeValidDeposit(deposit);

        reserve.addToWhitelist(user);

        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);

            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), user, deposit);

            reserve.depositAll();
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), 0);
        assertEq(ktt.balanceOf(address(reserve)), deposit);

        assertEq(kol.balanceOf(user), deposit);
        assertEq(kol.totalSupply(), deposit);

        _checkBacking(deposit, deposit, BPS);
    }

    function testDepositAllFor(address user, address receiver, uint deposit)
        public
    {
        _assumeValidAddress(user);
        _assumeValidAddress(receiver);
        _assumeValidDeposit(deposit);

        reserve.addToWhitelist(user);

        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);

            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), receiver, deposit);

            reserve.depositAllFor(receiver);
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), 0);
        assertEq(ktt.balanceOf(address(reserve)), deposit);

        assertEq(kol.balanceOf(receiver), deposit);
        assertEq(kol.totalSupply(), deposit);

        _checkBacking(deposit, deposit, BPS);
    }

    function testWithdraw(address user, uint deposit, uint withdraw) public {
        _assumeValidAddress(user);
        _assumeValidDepositAndWithdraw(deposit, withdraw);

        uint diff = deposit - withdraw;

        reserve.addToWhitelist(user);
        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);
            reserve.deposit(deposit);

            // Note that no approval is necessary.
            reserve.withdraw(withdraw);
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), withdraw);
        assertEq(ktt.balanceOf(address(reserve)), diff);

        assertEq(kol.balanceOf(user), diff);
        assertEq(kol.totalSupply(), diff);

        _checkBacking(diff, diff, BPS);
    }

    function testWithdrawTo(
        address user,
        address receiver,
        uint deposit,
        uint withdraw
    ) public {
        _assumeValidAddress(user);
        _assumeValidAddress(receiver);
        _assumeValidDepositAndWithdraw(deposit, withdraw);

        uint diff = deposit - withdraw;

        reserve.addToWhitelist(user);
        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);
            reserve.deposit(deposit);

            // Note that no approval is necessary.
            reserve.withdrawTo(receiver, withdraw);
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(receiver), withdraw);
        assertEq(ktt.balanceOf(address(reserve)), diff);

        assertEq(kol.balanceOf(user), diff);
        assertEq(kol.totalSupply(), diff);

        _checkBacking(diff, diff, BPS);
    }

    function testWithdrawAll(
        address user,
        uint deposit,
        uint withdraw
    ) public {
        _assumeValidAddress(user);
        _assumeValidDepositAndWithdraw(deposit, withdraw);

        uint diff = deposit - withdraw;

        reserve.addToWhitelist(user);
        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);
            reserve.deposit(deposit);

            // Send the difference of tokens that should not be withdrawn
            // to some address. Otherwise the withdrawAll call would withdraw
            // all tokens.
            kol.transfer(address(this), diff);

            // Note that no approval is necessary.
            reserve.withdrawAll();
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), withdraw);
        assertEq(ktt.balanceOf(address(reserve)), diff);

        assertEq(kol.balanceOf(user), 0);
        assertEq(kol.totalSupply(), diff);

        _checkBacking(diff, diff, BPS);
    }

    function testWithdrawAllTo(
        address user,
        address receiver,
        uint deposit,
        uint withdraw
    ) public {
        _assumeValidAddress(user);
        _assumeValidAddress(receiver);
        _assumeValidDepositAndWithdraw(deposit, withdraw);

        uint diff = deposit - withdraw;

        reserve.addToWhitelist(user);
        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);
            reserve.deposit(deposit);

            // Send the difference of tokens that should not be withdrawn
            // to some address. Otherwise the withdrawAllTo call would withdraw
            // all tokens.
            kol.transfer(address(this), diff);

            // Note that no approval is necessary.
            reserve.withdrawAllTo(receiver);
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(receiver), withdraw);
        assertEq(ktt.balanceOf(address(reserve)), diff);

        assertEq(kol.balanceOf(user), 0);
        assertEq(kol.balanceOf(receiver), 0);
        assertEq(kol.totalSupply(), diff);

        _checkBacking(diff, diff, BPS);
    }

    //--------------------------------------------------------------------------
    // Discount Zapper Deposits/Withdraws

    function testDepositAllWithDiscountFor(
        address zapper,
        address receiver,
        uint deposit,
        uint discount
    ) public {
        _assumeValidAddress(zapper);
        _assumeValidAddress(receiver);
        _assumeValidDeposit(deposit);

        // Set zapper instance.
        reserve.setDiscountZapper(zapper);

        // Expect revert if zapper equals receiver address.
        if (zapper == receiver) {
            vm.prank(zapper);

            vm.expectRevert(bytes("")); // Empty require statement.
            reserve.depositAllWithDiscountFor(receiver, discount);

            return;
        }

        // Expect revert if discount is higher than MAX_DISCOUNT.
        if (discount > MAX_DISCOUNT) {
            vm.prank(zapper);

            vm.expectRevert(bytes("")); // Empty require statement.
            reserve.depositAllWithDiscountFor(receiver, discount);

            return;
        }

        // Prepare deposit.
        ktt.mint(zapper, deposit);
        vm.prank(zapper);
        ktt.approve(address(reserve), deposit);

        uint discountedTokens = (deposit * discount) / BPS;

        // Calculate the new resulting backing of the reserve.
        uint kttSupply = deposit;
        uint newKOLSupply = kttSupply + discountedTokens;
        uint newMinBacking = newKOLSupply != 0
            ? (kttSupply * BPS) / newKOLSupply
            : BPS;

        // Expect revert if discount would decrease the backing below
        // DEFAULT_MIN_BACKING.
        if (newMinBacking < MIN_BACKING_IN_BPS) {
            vm.prank(zapper);

            vm.expectRevert(Errors.SupplyExceedsReserveLimit(
                BPS - discount,
                DEFAULT_MIN_BACKING
            ));
            reserve.depositAllWithDiscountFor(receiver, discount);

            return;
        }

        // Make deposit.
        vm.prank(zapper);
        reserve.depositAllWithDiscountFor(receiver, discount);

        assertEq(ktt.balanceOf(zapper), 0);
        assertEq(ktt.balanceOf(address(reserve)), deposit);

        assertEq(kol.balanceOf(zapper), 0);
        assertEq(kol.balanceOf(receiver), deposit + discountedTokens);
        assertEq(kol.totalSupply(), deposit + discountedTokens);

        _checkBacking(kttSupply, newKOLSupply, newMinBacking);
    }

    //--------------------------------------------------------------------------
    // Owner Deposits/Withdraws

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

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit DebtIncurred(address(this), 25e16);

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
        vm.expectRevert(Errors.SupplyExceedsReserveLimit(
                expectedBacking,
                MIN_BACKING_IN_BPS
        ));
        reserve.incurDebt(25e16 + 1);
    }

    function testPayDebt() public {
        // Deposit some KTTs so that reserve is unequal to zero.
        reserve.addToWhitelist(address(1));
        ktt.mint(address(1), 750e18);
        vm.startPrank(address(1));
        {
            ktt.approve(address(reserve), 750e18);
            reserve.deposit(750e18);
        }
        vm.stopPrank();

        // Incur some debt.
        reserve.incurDebt(250e18); // backing is 75%.
        _checkBacking(750e18, 1_000e18, 7_500);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit DebtPayed(address(this), 250e18);

        // Pay debt back.
        reserve.payDebt(250e18);
        _checkBacking(750e18, 750e18, BPS);
    }

    //--------------------------------------------------------------------------
    // Internal Functions

    function _checkBacking(
        uint wantReserve,
        uint wantSupply,
        uint wantBacking
    ) internal {
        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, wantReserve);
        assertEq(supply, wantSupply);
        assertEq(backingInBPS, wantBacking);
    }

    function _assumeValidAddress(address who) internal {
        vm.assume(who != address(0));
        vm.assume(who != address(this));
        vm.assume(who != address(kol));
        vm.assume(who != address(reserve));
    }

    function _assumeValidDeposit(uint deposit) internal {
        vm.assume(deposit < KTT_MAX_SUPPLY);
    }

    function _assumeValidDepositAndWithdraw(uint deposit, uint withdraw)
        internal
    {
        _assumeValidDeposit(deposit);

        vm.assume(withdraw < deposit);
    }

}