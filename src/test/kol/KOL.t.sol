// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "../../KOL.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";

/**
 * Errors library for KOL's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    bytes internal constant OnlyCallableByOwner =
        abi.encodeWithSignature("OnlyCallableByOwner()");

    bytes internal constant InvalidRecipient =
        abi.encodeWithSignature("KOL__InvalidRecipient()");

    bytes internal constant InvalidAmount =
        abi.encodeWithSignature("KOL__InvalidAmount()");
}

/**
 * @dev KOL Tests.
 */
contract KOLTest is Test {
    // SuT.
    KOL kol;

    function setUp() public {
        kol = new KOL();
    }

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != address(this));

        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        kol.addToWhitelist(address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        kol.removeFromWhitelist(address(1));
    }

    //--------------------------------------------------------------------------
    // Mint/Burn Tests

    function testMint(address caller) public {
        kol.addToWhitelist(caller);

        vm.startPrank(caller);

        kol.mint(address(1), 1e18);

        assertEq(kol.balanceOf(address(1)), 1e18);
        assertEq(kol.totalSupply(), 1e18);
    }

    function testBurn(address caller) public {
        kol.addToWhitelist(caller);

        vm.startPrank(caller);

        kol.mint(address(1), 1e18);
        kol.burn(address(1), 1e18);

        assertEq(kol.balanceOf(address(1)), 0);
        assertEq(kol.totalSupply(), 0);
    }

    //--------------------------------------------------------------------------
    // Whitelist Tests

    function testAddToWhitelist(address who) public {
        kol.addToWhitelist(who);

        assertTrue(kol.whitelist(who));
    }

    function testRemoveFromWhitelist(address who) public {
        kol.addToWhitelist(who);

        kol.removeFromWhitelist(who);

        assertTrue(!kol.whitelist(who));
    }

    //--------------------------------------------------------------------------
    // ERC20 Tests
    //
    // Note that only the modifiers validRecipient and validAmount are tested.
    // The ERC20 functionality is inherited from solmate's ERC20 implementation
    // and is trusted to be correct.

    function testApprove(address spender) public {
        if (spender == address(0) || spender == address(kol)) {
            vm.expectRevert(Errors.InvalidRecipient);
        }

        kol.approve(spender, 1e18);
    }

    function testTransfer(address to, uint amount) public {
        _mint(address(this), amount);

        if (to == address(0) || to == address(kol)) {
            vm.expectRevert(Errors.InvalidRecipient);
            kol.transfer(to, amount);
            return;
        }

        if (amount == 0) {
            vm.expectRevert(Errors.InvalidAmount);
            kol.transfer(to, amount);
            return;
        }

        kol.transfer(to, amount);
    }

    function testTransferFrom(address from, address to, uint amount) public {
        vm.assume(from != address(0));

        _mint(from, amount);

        vm.prank(from);
        kol.approve(address(this), amount);

        if (to == address(0) || to == address(kol)) {
            vm.expectRevert(Errors.InvalidRecipient);
            kol.transferFrom(from, to, amount);
            return;
        }

        if (amount == 0) {
            vm.expectRevert(Errors.InvalidAmount);
            kol.transferFrom(from, to, amount);
            return;
        }

        kol.transferFrom(from, to, amount);
    }

    function _mint(address to, uint amount) private {
        kol.addToWhitelist(address(this));
        kol.mint(to, amount);
    }

}
