// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Deposit and Withdraw Function Tests.
 */
contract ReserveDepositWithdraw is ReserveTest {

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
