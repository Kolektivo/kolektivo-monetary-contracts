// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import "../../zaps/DiscountZapper.sol";

import {Treasury} from "../../Treasury.sol";
import {Reserve} from "../../Reserve.sol";
import {KOL} from "../../KOL.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";

/**
 * Errors library for DiscountZapper's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner
        = abi.encodeWithSignature("OnlyCallableByOwner()");
}


/**
 * @dev DiscountZapper Integration Tests.
 *
 *      We do NOT mock any contract that have direct interactions with the
 *      Zapper!
 *      This is due to the Zapper contracts having a low internal complexity
 *      and the contract's interactions being the important thing here.
 */
contract DiscountZapperTest is DSTest {
    Vm internal constant vm = Vm(HEVM_ADDRESS);

    // SuT.
    DiscountZapper zapper;

    // Other contracts.
    Treasury treasury;
    Reserve reserve;
    KOL kol;

    // Test constants.
    uint constant MIN_BACKING_IN_BPS = 5_000; // 50%

    // Constants copied from SuT.
    uint private constant BPS = 10_000;
    uint private constant MAX_DISCOUNT = 3_000;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event DiscountUpdated(address indexed asset,
                          uint oldDiscount,
                          uint newDiscount);

    function setUp() public {
        treasury = new Treasury();

        kol = new KOL();

        reserve = new Reserve(
            address(kol),
            address(treasury),
            MIN_BACKING_IN_BPS
        );

        zapper = new DiscountZapper(address(treasury), address(reserve));
    }

    //--------------------------------------------------------------------------
    // User Tests

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != address(this));

        // This is not strictly necessary because the onlyOwner modifier is
        // executed checking whether the treasury supports the asset.
        address asset = address(1);
        _supportAssetByTreasury(asset);

        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        zapper.setDiscountForAsset(asset, 0);
    }

    function testAddDiscountForAsset(
        address asset,
        uint discount
    ) public {
        _assumeValidAddress(asset);
        vm.assume(discount <= MAX_DISCOUNT);

        // Set asset as being supported by treasury.
        _supportAssetByTreasury(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit DiscountUpdated(asset, 0, discount);

        // Set discount for asset.
        zapper.setDiscountForAsset(asset, discount);

        // Expect discount to be updated.
        assertEq(zapper.discountPerAsset(asset), discount);
    }

    function testAddDiscountForAssetFailsIfAssetNotSupportedByTreasury(
        address asset,
        uint discount
    ) public {
        _assumeValidAddress(asset);
        vm.assume(discount <= MAX_DISCOUNT);

        vm.expectRevert(bytes("")); // Empty require statement.
        zapper.setDiscountForAsset(asset, discount);
    }

    function testAddDiscountForAssetFailsIfDiscountTooHigh(
        address asset,
        uint discount
    ) public {
        _assumeValidAddress(asset);
        vm.assume(discount > MAX_DISCOUNT);

        // Set asset as being supported by treasury.
        _supportAssetByTreasury(asset);

        vm.expectRevert(bytes("")); // Empty require statement.
        zapper.setDiscountForAsset(asset, discount);
    }

    //--------------------------------------------------------------------------
    // Internal Functions

    function _supportAssetByTreasury(address asset) internal {
        // Create oracle for asset.
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Set asset as being supported by treasury.
        treasury.supportAsset(asset, address(oracle));

        // Set asset as being supported for bonding operations by treasury.
        treasury.supportAssetForBonding(asset);
    }

    function _assumeValidAddress(address who) internal {
        vm.assume(who != address(0));
        vm.assume(who != address(this));
        vm.assume(who != address(treasury));
        vm.assume(who != address(reserve));
        vm.assume(who != address(kol));
    }

}
