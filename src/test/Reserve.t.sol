// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "../Reserve.sol";

import {HEVM} from "./utils/HEVM.sol";
import {ERC20Mock} from "./utils/mocks/ERC20Mock.sol";

contract ReserveTest is DSTest {
    HEVM internal constant EVM = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // SuT
    Reserve reserve;

    // Mocks
    ERC20Mock kol;
    ERC20Mock ktt;

    // Test constants
    uint constant DEFAULT_MIN_BACKING = 7_500; // 75%
    uint constant KOL_DECIMALS = 18;
    uint constant KTT_DECIMALS = 9;

    // Constants copied from SuT.
    uint constant BPS = 10_000;
    uint constant MIN_BACKING_IN_BPS = 5_000; // 50%

    // Other constants
    uint constant KTT_MAX_SUPPLY = 1_000_000_000e18;

    function setUp() public {
        kol = new ERC20Mock("KOL", "KOL Token", uint8(KOL_DECIMALS));
        ktt = new ERC20Mock("KTT", "KTT Token", uint8(KTT_DECIMALS));

        reserve = new Reserve(
            address(kol),
            address(ktt),
            DEFAULT_MIN_BACKING
        );
    }

    //--------------------------------------------------------------------------
    // Deployment Tests

    function testInvariants() public {
        // Ownable invariants.
        assertEq(reserve.owner(), address(this));

        // Reserve status.
        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, 0);
        assertEq(supply, 0);
        assertEq(backingInBPS, BPS);
    }

    function testConstructor() public {
        // Constructor arguments.
        assertEq(reserve.kol(), address(kol));
        assertEq(reserve.ktt(), address(ktt));
        assertEq(reserve.minBackingInBPS(), DEFAULT_MIN_BACKING);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        if (caller == reserve.owner()) {
            return;
        }

        EVM.startPrank(caller);

        //----------------------------------
        // Debt Management

        try reserve.setMinBackingInBPS(DEFAULT_MIN_BACKING) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try reserve.incurDebt(1) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try reserve.payDebt(1) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        //----------------------------------
        // Whitelist Management

        try reserve.addToWhitelist(address(0)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try reserve.removeFromWhitelist(address(0)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }
    }

    //----------------------------------
    // Debt Management

    function testSetMinBackingInBPS(uint to) public {
        if (to >= MIN_BACKING_IN_BPS) {
            reserve.setMinBackingInBPS(to);

            assertEq(reserve.minBackingInBPS(), to);
        } else {
            try reserve.setMinBackingInBPS(to) {
                revert();
            } catch {
                // Fails due to being smaller than MIN_BACKING_IN_BPS.
            }
        }
    }

    function testIncurDebt() public {
        // Note that 75e7 = 0.75e9

        // Deposit some KTTs so that reserve is unequal to zero.
        reserve.addToWhitelist(address(1));
        ktt.mint(address(1), 75e7);
        EVM.startPrank(address(1));
        {
            ktt.approve(address(reserve), 75e7);
            reserve.deposit(75e7);
        }
        EVM.stopPrank();

        // max debt amount is 25e7 because 75% is debt limit and 75e7 is
        // in the reserve.
        reserve.incurDebt(25e7);

        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, 75e7 * 1e9);
        assertEq(supply, 1e9 * 1e9);
        assertEq(backingInBPS, DEFAULT_MIN_BACKING);
    }

    function testFailIncureDebtWithNoReserve() public {
        // Fails due to reserve being zero.
        reserve.incurDebt(1);
    }

    function testFailIncurDebtMoreThanAllowed() public {
        // Deposit some KTTs so that reserve is unequal to zero.
        reserve.addToWhitelist(address(1));
        ktt.mint(address(1), 75e7);
        EVM.startPrank(address(1));
        {
            ktt.approve(address(reserve), 75e7);
            reserve.deposit(75e7);
        }
        EVM.stopPrank();

        // max debt amount is 25e7 because 75% is debt limit and 75e7 is
        // in the reserve.
        // Fails with SupplyExceedsReserveLimit.
        reserve.incurDebt(25e7 + 1);
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

    //--------------------------------------------------------------------------
    // User Tests

    function testDeposit(address user) public {
        if (user == address(0)) {
            return;
        }

        reserve.addToWhitelist(user);

        ktt.mint(user, 1e9);

        EVM.startPrank(user);
        {
            ktt.approve(address(reserve), 1e9);
            reserve.deposit(1e9);
        }
        EVM.stopPrank();

        assertEq(ktt.balanceOf(user), 0);
        assertEq(ktt.balanceOf(address(reserve)), 1e9);

        assertEq(kol.balanceOf(user), 1e18);
        assertEq(kol.totalSupply(), 1e18);

        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, 1e18);
        assertEq(supply, 1e18);
        assertEq(backingInBPS, BPS);
    }

    function testWithdraw(address user) public {
        if (user == address(0)) {
            return;
        }

        reserve.addToWhitelist(user);
        ktt.mint(user, 10e9);

        EVM.startPrank(user);
        {
            ktt.approve(address(reserve), 10e9);
            reserve.deposit(10e9);
            reserve.withdraw(5e18); // Withdraw half of the KOL tokens.
        }
        EVM.stopPrank();

        assertEq(ktt.balanceOf(user), 5e9);
        assertEq(ktt.balanceOf(address(reserve)), 5e9);

        assertEq(kol.balanceOf(user), 5e18);
        assertEq(kol.totalSupply(), 5e18);

        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, 5e18);
        assertEq(supply, 5e18);
        assertEq(backingInBPS, BPS);
    }

}
