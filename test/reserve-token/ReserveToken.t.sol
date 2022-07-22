// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/ReserveToken.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";

/**
 * Errors library for ReserveTokens's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/TSOwnable.sol
    bytes internal constant OnlyCallableByOwner =
        abi.encodeWithSignature("OnlyCallableByOwner()");

    bytes internal constant InvalidRecipient =
        abi.encodeWithSignature("ReserveToken__InvalidRecipient()");

    bytes internal constant InvalidAmount =
        abi.encodeWithSignature("ReserveToken__InvalidAmount()");

    bytes internal constant NotMintBurner =
        abi.encodeWithSignature("ReserveToken__NotMintBurner()");
}

/**
 * @dev ReserveToken Tests.
 */
contract ReserveTokenTest is Test {
    // SuT.
    ReserveToken token;

    // Events copied from SuT.
    event SetMintBurner(
        address indexed oldMintBurner,
        address indexed newMintBurner
    );

    function setUp() public {
        token = new ReserveToken("Reserve Token", "RT", address(this));
    }

    function testDeployment() public {
        // solrocket/TSOwnable.sol
        assertEq(token.owner(), address(this));
        assertEq(token.pendingOwner(), address(0));

        // ERC20
        assertEq(token.decimals(), uint8(18));

        // Constructor arguments.
        assertEq(token.name(), "Reserve Token");
        assertEq(token.symbol(), "RT");
        assertEq(token.mintBurner(), address(this));
    }

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != address(this));

        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        token.setMintBurner(address(1));
    }

    function testSetMintBurner(address who) public {
        if (who != token.mintBurner()) {
            vm.expectEmit(true, true, true, true);
            emit SetMintBurner(token.mintBurner(), who);
        }

        token.setMintBurner(who);
        assertEq(token.mintBurner(), who);
    }

    //--------------------------------------------------------------------------
    // Mint/Burn Tests

    function testMint(address to, uint amount) public {
        // Expect revert for invalid recipient.
        if (to == address(0) || to == address(token)) {
            vm.expectRevert(Errors.InvalidRecipient);
            token.mint(to, amount);
            return;
        }

        // Expect revert for invalid amount.
        if (amount == 0) {
            vm.expectRevert(Errors.InvalidAmount);
            token.mint(to, amount);
            return;
        }

        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testBurn(address who, uint mint, uint burn) public {
        vm.assume(who != address(0) && who != address(token));
        vm.assume(mint != 0 && mint >= burn);

        token.mint(who, mint);

        // Expect revert for invalid amount.
        if (burn == 0) {
            vm.expectRevert(Errors.InvalidAmount);
            token.burn(who, burn);
            return;
        }

        token.burn(who, burn);

        assertEq(token.balanceOf(who), mint-burn);
        assertEq(token.totalSupply(), mint-burn);
    }

}
