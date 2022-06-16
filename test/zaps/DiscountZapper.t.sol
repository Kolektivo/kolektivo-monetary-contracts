// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import {DiscountZapper} from "src/zaps/DiscountZapper.sol";
import {Treasury} from "src/Treasury.sol";
import {Reserve} from "src/Reserve.sol";
import {KOL} from "src/KOL.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";

/**
 * Errors library for DiscountZapper's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    bytes internal constant OnlyCallableByOwner =
        abi.encodeWithSignature("OnlyCallableByOwner()");
}

/**
 * @dev DiscountZapper Integration Tests.
 *
 *      We do NOT mock any contract that have direct interactions with the
 *      Zapper!
 *      This is due to the Zapper contracts having a low internal complexity
 *      and the contract's interactions being the important thing to test.
 */
contract DiscountZapperTest is Test {
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
    uint private constant MAX_DISCOUNT = 3_000; // 30%

    // Constants copied from elastic-receipt-token.
    // Note that this is the max supply of KTT tokens supported by the Treasury.
    // For more info see elastic-receipt-token.
    uint internal constant MAX_SUPPLY = 1_000_000_000e18;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event DiscountUpdated(
        address indexed asset,
        uint oldDiscount,
        uint newDiscount
    );

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

    // Note that this test does not use mocks for the Treasury, Reserve and
    // KOL token. Only the Oracle and ERC20 asset token are mocked.
    // This means the setup is quite cumbersome for a test BUT also reflects
    // the production system more realistically.
    function testZap(address caller, uint amount) public {
        vm.assume(amount != 0 && amount < MAX_SUPPLY);

        // @todo Adjust test to have:
        // - random price of asset
        // - random discount for asset

        // Setup asset mock and oracle mock.
        ERC20Mock asset = new ERC20Mock("TOKEN", "TKN", uint8(18));
        OracleMock oracle = new OracleMock();

        // Set asset price in oracle.
        oracle.setDataAndValid(1e18, true); // price is 1 USD.

        // Mint assets to caller.
        asset.mint(caller, amount);

        // Setup Treasury
        // --------------
        // Whitelist Zapper for Treasury bonding operations.
        treasury.addToWhitelist(address(zapper));

        // Mark asset as being supported in Treasury.
        treasury.supportAsset(address(asset), address(oracle));

        // Mark asset as being bondable in Treasury.
        treasury.supportAssetForBonding(address(asset));

        // Setup Reserve
        // -------------
        // Whitelist Reserve to mint KOL tokens.
        kol.addToWhitelist(address(reserve));

        // Set Zapper in Reserve.
        reserve.setDiscountZapper(address(zapper));

        // Setup Caller/User
        // -----------------
        // Give permission from caller to Zapper.
        vm.prank(caller);
        asset.approve(address(zapper), amount);

        // Execution
        // ---------
        // Let caller call Zapper's zap() function.
        vm.prank(caller);
        zapper.zap(address(asset), amount);

        // Checks
        // ------
        // Check that caller received the correct amount of KOL tokens.
        assertEq(kol.balanceOf(caller), amount);

        // Check that Zapper does not hold any tokens.
        assertEq(kol.balanceOf(address(zapper)), 0);
        assertEq(treasury.balanceOf(address(zapper)), 0); // KTT token.

    }

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != address(this));

        // This is not strictly necessary because the onlyOwner modifier is
        // executed checking whether the treasury supports the asset.
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));
        _supportAssetByTreasury(asset);

        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        zapper.setDiscountForAsset(asset, 0);
    }

    function testAddDiscountForAsset(uint discount) public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        // Set asset as being supported by treasury.
        _supportAssetByTreasury(asset);

        // Expect revert if discount is higher than MAX_DISCOUNT.
        if (discount > MAX_DISCOUNT) {
            vm.expectRevert(bytes("")); // Empty require statement.
            zapper.setDiscountForAsset(asset, discount);
            return;
        }

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit DiscountUpdated(asset, 0, discount);

        // Set discount for asset.
        zapper.setDiscountForAsset(asset, discount);

        // Expect discount to be updated.
        assertEq(zapper.discountPerAsset(asset), discount);
    }

    function testAddDiscountForAssetFailsIfAssetNotSupportedByTreasury(
        uint discount
    ) public {
        vm.assume(discount <= MAX_DISCOUNT);

        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

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

}
