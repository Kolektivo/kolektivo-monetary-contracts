// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Deposit and Withdraw Function Tests.
 */
contract ReserveDepositWithdraw is ReserveTest {

    // @todo Add tests for depositFor, depositAll etc.

    function testDeposit(address user, uint deposit) public {
        vm.assume(user != address(0) && user != address(reserve));
        vm.assume(deposit < KTT_MAX_SUPPLY);

        reserve.addToWhitelist(user);

        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);

            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            //emit KolMinted(user, deposit);
            emit Transfer(address(0), user, deposit);

            reserve.deposit(deposit);
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), 0);
        assertEq(ktt.balanceOf(address(reserve)), deposit);

        assertEq(kol.balanceOf(user), deposit);
        assertEq(kol.totalSupply(), deposit);

        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, deposit);
        assertEq(supply, deposit);
        assertEq(backingInBPS, BPS);
    }

    function testWithdraw(address user, uint deposit, uint withdraw) public {
        vm.assume(user != address(0) && user != address(reserve));
        vm.assume(deposit  < KTT_MAX_SUPPLY);
        vm.assume(withdraw < deposit);

        reserve.addToWhitelist(user);
        ktt.mint(user, deposit);

        vm.startPrank(user);
        {
            ktt.approve(address(reserve), deposit);
            reserve.deposit(deposit);

            // Note that no approval is necessary.
            reserve.withdraw(withdraw); // Withdraw KOL tokens.
        }
        vm.stopPrank();

        assertEq(ktt.balanceOf(user), withdraw);
        assertEq(ktt.balanceOf(address(reserve)), deposit - withdraw);

        assertEq(kol.balanceOf(user), deposit - withdraw);
        assertEq(kol.totalSupply(), deposit - withdraw);

        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, deposit - withdraw);
        assertEq(supply, deposit - withdraw);
        assertEq(backingInBPS, BPS);
    }

}
