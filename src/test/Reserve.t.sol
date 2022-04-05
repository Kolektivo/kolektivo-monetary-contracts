// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "ds-test/test.sol";

import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import "../Reserve.sol";

import {ERC20Mock} from "./utils/mocks/ERC20Mock.sol";
import {OracleMock} from "./utils/mocks/OracleMock.sol";

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
    ERC20Mock kol;
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
        kol = new ERC20Mock("KOL", "KOL Token", uint8(KOL_DECIMALS));
        ktt = new ERC20Mock("KTT", "KTT Token", uint8(KTT_DECIMALS));
        cusd = new ERC20Mock("cUSD", "cUSD Token", uint8(CUSD_DECIMALS));

        // Set up oracles.
        kolPriceOracle = new OracleMock();
        kolPriceOracle.setDataAndValid(ONE_USD, true);
        cusdPriceOracle = new OracleMock();
        cusdPriceOracle.setDataAndValid(ONE_USD, true);

        reserve = new Reserve(
            address(kol),
            address(ktt),
            address(cusd),
            DEFAULT_MIN_BACKING,
            address(kolPriceOracle),
            address(cusdPriceOracle)
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
        assertEq(reserve.cusd(), address(cusd));
        assertEq(reserve.minBackingInBPS(), DEFAULT_MIN_BACKING);
        assertEq(reserve.kolPriceOracle(), address(kolPriceOracle));
        assertEq(reserve.cusdPriceOracle(), address(cusdPriceOracle));
    }

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != reserve.owner());

        vm.startPrank(caller);

        //----------------------------------
        // Oracle Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setCUSDPriceOracle(address(0));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setKOLPriceOracle(address(0));

        //----------------------------------
        // Price Floor/Ceiling Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setPriceFloor(0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setPriceCeiling(0);

        //----------------------------------
        // Debt Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setMinBackingInBPS(DEFAULT_MIN_BACKING);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.incurDebt(1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.payDebt(1);

        //----------------------------------
        // Whitelist Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.addToWhitelist(address(0));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.removeFromWhitelist(address(0));
    }

    //----------------------------------
    // Oracle Management

    function testSetCUSDPriceOracle(bool oracleIsValid) public {
        address oldOracle = address(cusdPriceOracle);

        cusdPriceOracle = new OracleMock();
        cusdPriceOracle.setDataAndValid(ONE_USD, oracleIsValid);

        if (oracleIsValid) {
            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            emit AssetOracleUpdated(
                address(cusd),
                oldOracle,
                address(cusdPriceOracle)
            );
        } else {
            // Expect error.
            vm.expectRevert(
                Errors.StalePriceDeliveredByOracle(
                    address(cusd), address(cusdPriceOracle)
                )
            );
        }

        reserve.setCUSDPriceOracle(address(cusdPriceOracle));

        if (oracleIsValid) {
            // Expect oracle to be updated.
            assertEq(reserve.cusdPriceOracle(), address(cusdPriceOracle));
        } else {
            // Expect oracle to not being updated.
            assertEq(reserve.cusdPriceOracle(), oldOracle);
        }
    }

    function testSetKOLPriceOracle(bool oracleIsValid) public {
        address oldOracle = address(kolPriceOracle);

        kolPriceOracle = new OracleMock();
        kolPriceOracle.setDataAndValid(ONE_USD, oracleIsValid);

        if (oracleIsValid) {
            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            emit AssetOracleUpdated(
                address(kol),
                oldOracle,
                address(kolPriceOracle)
            );
        } else {
            // Expect error.
            vm.expectRevert(
                Errors.StalePriceDeliveredByOracle(
                    address(kol), address(kolPriceOracle)
                )
            );
        }

        reserve.setKOLPriceOracle(address(kolPriceOracle));

        if (oracleIsValid) {
            // Expect oracle to be updated.
            assertEq(reserve.kolPriceOracle(), address(kolPriceOracle));
        } else {
            // Expect oracle to not being updated.
            assertEq(reserve.kolPriceOracle(), oldOracle);
        }
    }

    //----------------------------------
    // Price Floor/Ceiling Management

    function testSetPriceFloorAndCeiling(uint floor, uint ceiling) public {
        vm.assume(floor <= ceiling);
        vm.assume(floor != 0 && ceiling != 0);

        // Set price ceiling first.
        vm.expectEmit(true, true, true, true);
        emit PriceCeilingChanged(0, ceiling);

        reserve.setPriceCeiling(ceiling);

        // Afterwards the price floor.
        vm.expectEmit(true, true, true, true);
        emit PriceFloorChanged(0, floor);

        reserve.setPriceFloor(floor);
    }

    //----------------------------------
    // Debt Management

    function testSetMinBackingInBPS(uint to) public {
        uint before = reserve.minBackingInBPS();

        if (to < MIN_BACKING_IN_BPS) {
            try reserve.setMinBackingInBPS(to) {
                revert();
            } catch {
                // Fails due to being smaller than MIN_BACKING_IN_BPS.
            }
        } else {
            // Only expect an event if state changed.
            if (before != to)   {
                vm.expectEmit(true, true, true, true);
                emit MinBackingInBPSChanged(before, to);
            }

            reserve.setMinBackingInBPS(to);

            assertEq(reserve.minBackingInBPS(), to);
        }
    }

    function testIncurDebt() public {
        // Note that 75e16 = 0.75e18 = 0.75$.

        // Deposit some KTTs so that reserve is unequal to zero.
        reserve.addToWhitelist(address(1));
        ktt.mint(address(1), 75e16);
        vm.startPrank(address(1));
        {
            ktt.approve(address(reserve), 75e16);
            reserve.deposit(75e16);
        }
        vm.stopPrank();

        // max debt amount is 25e16 because 75% is debt limit and 75e16 is
        // in the reserve.
        reserve.incurDebt(25e16);

        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, 75e16);
        assertEq(supply, 1e18);
        assertEq(backingInBPS, DEFAULT_MIN_BACKING);
    }

    function testFailIncureDebtWithNoReserve() public {
        // Fails due to reserve being zero.
        reserve.incurDebt(1);
    }

    // @todo Test is on fail because expectRevert is not working.
    function testFailIncurDebtMoreThanAllowed() public {
        // Note that 75e16 = 0.75e18 = 0.75$.

        // Deposit some KTTs so that reserve is unequal to zero.
        reserve.addToWhitelist(address(1));
        ktt.mint(address(1), 75e16);
        vm.startPrank(address(1));
        {
            ktt.approve(address(reserve), 75e16);
            reserve.deposit(75e16);
        }
        vm.stopPrank();

        // max debt amount is 25e16 because 75% is debt limit and 75e16 is
        // in the reserve.
        uint expectedBacking = 7_500 - 1; // 0.75% - 1 bps.
        vm.expectRevert(
            Errors.SupplyExceedsReserveLimit(
                expectedBacking,
                MIN_BACKING_IN_BPS
            )
        );
        reserve.incurDebt(25e16 + 1);
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
            emit KolMinted(user, deposit);

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
