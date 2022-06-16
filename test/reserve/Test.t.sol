// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/Reserve.sol";

import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";
import {OracleMock} from "../utils/mocks/OracleMock.sol";

/**
 * Errors library for Reserve's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner
        = abi.encodeWithSignature("OnlyCallableByOwner()");

    function SupplyExceedsReserveLimit(uint backingInBPS, uint minBackingInBPS)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Reserve__SupplyExceedsReserveLimit(uint,uint)",
            backingInBPS,
            minBackingInBPS
        );
    }

    bytes internal constant OnlyCallableByDiscountZapper
        = abi.encodeWithSignature("Reserve__OnlyCallableByDiscountZapper()");
}

/**
 * @dev Root contract for Reserve Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
contract ReserveTest is Test {
    // SuT.
    Reserve reserve;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event BackingInBPSChanged(uint oldBackingInBPS, uint newBackingInBPS);
    event PriceFloorChanged(uint oldPriceFloor, uint newPriceFloor);
    event PriceCeilingChanged(uint oldPriceCeiling, uint newPriceCeiling);
    event MinBackingInBPSChanged(
        uint oldMinBackingInBPS,
        uint newMinBackingInBPS
    );
    event DiscountZapperChanged(address indexed from, address indexed to);
    event DebtIncurred(address indexed who, uint ktts);
    event DebtPayed(address indexed who, uint ktts);

    // Events copied from KOL tokens.
    // Note that the Event declarations are needed to test for emission.
    // Note that a transfer event from/to the zero address indicates a
    // mint/burn.
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // Mocks.
    ERC20Mock kol;
    ERC20Mock ktt;

    // Test constants.
    uint constant DEFAULT_MIN_BACKING = 7_500; // 75%

    // Constants copied from SuT.
    uint constant BPS = 10_000;
    uint constant MIN_BACKING_IN_BPS = 5_000; // 50%
    uint constant MAX_DISCOUNT = 3_000; // 30%

    // Other constants.
    uint constant KTT_MAX_SUPPLY = 1_000_000_000e18;

    uint8 constant KOL_DECIMALS = 18;
    uint8 constant KTT_DECIMALS = 18;

    uint constant ONE_USD = 1e18;

    function setUp() public {
        // Set up tokens.
        kol = new ERC20Mock("KOL", "KOL Token", uint8(KOL_DECIMALS));
        ktt = new ERC20Mock("KTT", "KTT Token", uint8(KTT_DECIMALS));

        reserve = new Reserve(
            address(kol),
            address(ktt),
            DEFAULT_MIN_BACKING
        );
    }

}
