// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import "../../Reserve.sol";

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
            "SupplyExceedsReserveLimit(uint,uint)",
            backingInBPS,
            minBackingInBPS
        );
    }

    function StalePriceDeliveredByOracle(address asset, address oracle)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "StalePriceDeliveredByOracle(address,address)",
            asset,
            oracle
        );
    }
}

/**
 * @dev Root contract for Reserve Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
contract ReserveTest is DSTest {
    Vm internal constant vm = Vm(HEVM_ADDRESS);

    // SuT.
    Reserve reserve;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event BackingInBPSChanged(uint oldBackingInBPS, uint newBackingInBPS);
    event AssetOracleUpdated(address indexed asset,
                             address indexed oldOracle,
                             address indexed newOracle);
    event PriceFloorChanged(uint oldPriceFloor, uint newPriceFloor);
    event PriceCeilingChanged(uint oldPriceCeiling, uint newPriceCeiling);
    event MinBackingInBPSChanged(uint oldMinBackingInBPS,
                                 uint newMinBackingInBPS);
    event IncurredDebt(address indexed who, uint ktts);
    event PayedDebt(address indexed who, uint ktts);
    event KolMinted(address indexed to, uint ktts);
    event KolBurned(address indexed from, uint ktts);

    // Mocks.
    ERC20Mock ktt;
    ERC20Mock cusd;
    OracleMock kolPriceOracle;
    OracleMock cusdPriceOracle;

    // Test constants.
    uint constant DEFAULT_MIN_BACKING = 7_500; // 75%

    // Constants copied from SuT.
    uint constant BPS = 10_000;
    uint constant MIN_BACKING_IN_BPS = 5_000; // 50%

    // Other constants.
    uint constant KTT_MAX_SUPPLY = 1_000_000_000e18;

    uint8 constant KOL_DECIMALS = 18;
    uint8 constant KTT_DECIMALS = 18;
    uint8 constant CUSD_DECIMALS = 18;

    uint constant ONE_USD = 1e18;

    function setUp() public {
        // Set up tokens.
        ktt = new ERC20Mock("KTT", "KTT Token", uint8(KTT_DECIMALS));
        cusd = new ERC20Mock("cUSD", "cUSD Token", uint8(CUSD_DECIMALS));

        // Set up oracles.
        kolPriceOracle = new OracleMock();
        kolPriceOracle.setDataAndValid(ONE_USD, true);
        cusdPriceOracle = new OracleMock();
        cusdPriceOracle.setDataAndValid(ONE_USD, true);

        reserve = new Reserve(
            address(ktt),
            address(cusd),
            DEFAULT_MIN_BACKING,
            address(kolPriceOracle),
            address(cusdPriceOracle)
        );
    }

}
