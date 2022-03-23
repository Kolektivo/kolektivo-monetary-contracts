// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "../KOL.sol";

import {HEVM} from "./utils/HEVM.sol";

contract KOLTest is DSTest {
    HEVM internal constant EVM = HEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // SuT.
    KOL kol;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event MintBurnerChanged(address oldMintBurner, address newMintBurner);

    // Test constants.
    address constant MINT_BURNER = address(1);

    function setUp() public {
        kol = new KOL(MINT_BURNER);
    }

    //--------------------------------------------------------------------------
    // Deployment Tests

    function testInvariants() public {
        // Ownable invariants.
        assertEq(kol.owner(), address(this));

        // ERC20 invariants.
        assertEq(kol.name(), "Kolektivo Reserve Token");
        assertEq(kol.symbol(), "KOL");
        assertEq(kol.decimals(), uint8(18));
    }

    function testConstructor() public {
        // Constructor arguments.
        assertEq(kol.mintBurner(), MINT_BURNER);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        if (caller == kol.owner()) {
            return;
        }

        EVM.startPrank(caller);

        try kol.setMintBurner(address(2)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }
    }

    function testSetMintBurner(address to) public {
        if (to == address(kol)     ||
            to == kol.owner()      ||
            to == kol.mintBurner() ||
            to == address(0)
        ) {
            return;
        }
        address oldMintBurner = kol.mintBurner();

        // Expect event emission.
        EVM.expectEmit(true, true, true, true);
        emit MintBurnerChanged(oldMintBurner, to);

        kol.setMintBurner(to);
        assertEq(kol.mintBurner(), to);
    }

    function testFailSetMintBurnerToKOLAddress() public {
        kol.setMintBurner(address(kol));
    }

    function testFailSetMintBurnerToOwner() public {
        kol.setMintBurner(kol.owner());
    }

    function testFailSetMintBurnerToCurrentMintBurner() public {
        kol.setMintBurner(kol.mintBurner());
    }

    function testFailSetMintBurnerToZeroAddress() public {
        kol.setMintBurner(address(0));
    }

    //--------------------------------------------------------------------------
    // onlyMintBurner Tests

    function testOnlyMintBurnerFunctionsNotPubliclyCallable(address caller)
        public
    {
        if (caller == kol.mintBurner()) {
            return;
        }

        EVM.startPrank(caller);

        try kol.mint(caller, 1e18) {
            revert();
        } catch {
            // Fails with OnlyCallableByMintBurner;
        }

        try kol.burn(caller, 1e18) {
            revert();
        } catch {
            // Fails with OnlyCallableByMintBurner;
        }
    }


    function testMint(address to, uint amount) public {
        EVM.prank(MINT_BURNER);
        kol.mint(to, amount);

        assertEq(kol.balanceOf(to), amount);
        assertEq(kol.totalSupply(), amount);
    }

    function testBurn(address to, uint amount) public {
        if (amount == 0) {
            return;
        }

        EVM.startPrank(MINT_BURNER);
        {
            kol.mint(to, amount);
            kol.burn(to, amount - 1);
        }
        EVM.stopPrank();

        assertEq(kol.balanceOf(to), 1);
        assertEq(kol.totalSupply(), 1);
    }

}
