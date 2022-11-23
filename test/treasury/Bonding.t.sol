// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./Test.t.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";

/**
 * @dev Bonding Function Tests.
 */
contract TreasuryBonding is TreasuryTest {

    //--------------------------------------------------------------------------
    // Constants

    // 1 USD with 18 decimals precision.
    uint private constant ONE_USD = 1e18;

    //--------------------------------------------------------------------------
    // Modifiers

    modifier validAmount(uint amount, bool fail) {
        if (amount > 0 && amount < MAX_SUPPLY) {
            _;
        } else {
            if (fail) {
                revert();
            }
        }
    }

    //--------------------------------------------------------------------------
    // setUp Functions

    function setUpForBonding(
        uint price,
        uint amount,
        uint decimals
    ) public returns (ERC20Mock, OracleMock) {
        // Create token and oracle.
        ERC20Mock token = new ERC20Mock("TKN", "Token", uint8(decimals));
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(price, true);

        // Let treasury support token for bonding.
        treasury.registerERC20(address(token), address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
        treasury.listERC20AsBondable(address(token));

        // Mint tokens.
        token.approve(address(treasury), type(uint).max);
        token.mint(address(this), amount);

        return (token, oracle);
    }

    //--------------------------------------------------------------------------
    // Tests

    //----------------------------------
    // Bond & Redeem disabled for invalid oracles

    function testFailBondingDisabledIfOracleInvalid(uint amount)
        public
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(ONE_USD, amount, 18);

        // Set token's oracle to invalid.
        oracle.setValid(false);

        // Fails with StalePriceDeliveredByOracle.
        treasury.bondERC20(address(token), amount);
    }

    function testFailBondingDisabledIfOraclePriceIsZero(uint amount)
        public
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(ONE_USD, amount, 18);

        // Set token's oracle price to 0.
        oracle.setData(0);

        // Fails with StalePriceDeliveredByOracle.
        treasury.bondERC20(address(token), amount);
    }

    function testFailRedeemDisabledIfOracleInvalid(uint amount)
        public
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(ONE_USD, amount, 18);

        // Mark token as redeemable.
        treasury.listERC20AsRedeemable(address(token));

        // Bond tokens.
        treasury.bondERC20(address(token), amount);

        // Set token's oracle to invalid.
        oracle.setValid(false);

        // Fails with StalePriceDelivered.
        treasury.redeemERC20(address(token), amount);
    }

    function testFailRedeemDisabledIfOraclePriceIsZero(uint amount)
        public
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(ONE_USD, amount, 18);

        // Mark token as redeemable.
        treasury.listERC20AsRedeemable(address(token));

        // Bond tokens.
        treasury.bondERC20(address(token), amount);

        // Set oracle's price to zero.
        oracle.setData(0);

        // Fails with StalePriceDelivered.
        treasury.redeemERC20(address(token), amount);
    }

    //----------------------------------
    // Bonding

    function testFailCanNotRedeemToZero(uint amount)
        public
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(ONE_USD, amount, 18);

        // Mark token as redeemable.
        treasury.listERC20AsRedeemable(address(token));

        // Bond tokens.
        treasury.bondERC20(address(token), amount);

        // Redeem all tokens.
        // Fails with a Division by 0 in ElasticReceiptToken.
        treasury.redeemERC20(address(token), amount);
    }

    function testBondingAndRedeeming(uint amount)
        public
        validAmount(amount, false)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(ONE_USD, amount, 18);

        // Mark token as redeemable.
        treasury.listERC20AsRedeemable(address(token));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20sBonded(address(this), address(token), amount);

        // Bond tokens.
        treasury.bondERC20(address(token), amount);

        // Check that address(this) received amount of KTT tokens.
        assertEq(treasury.balanceOf(address(this)), amount);
        // Check that address(this) does not have any tokens anymore.
        assertEq(token.balanceOf(address(this)), 0);
        // Check that treasury now holds the tokens.
        assertEq(token.balanceOf(address(treasury)), amount);
        // Check that treasury's total valuation equals the amount bonded.
        assertEq(treasury.totalValuation(), amount);
        // Check that KTT's total supply equals the treasury's valuation.
        assertEq(treasury.totalSupply(), amount);

        // Unbond tokens.
        // Note that we cannot unbond all tokens.
        if (amount == 1) {
            return;
        }
        uint tokensUnbonded = amount - 1;

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20sRedeemed(address(this), address(token), tokensUnbonded);

        treasury.redeemERC20(address(token), tokensUnbonded);

        // Check that address(this) received the tokens unbonded.
        assertEq(token.balanceOf(address(this)), tokensUnbonded);
        // Check that address(this)'s KTT tokens got burned.
        assertEq(treasury.balanceOf(address(this)), amount - tokensUnbonded);
        // Check that treasury's total valuation decreased by the amount of
        // tokens unbonded.
        assertEq(treasury.totalValuation(), amount - tokensUnbonded);
        // Check that KTT's total supply equals the treasury's valuation.
        assertEq(treasury.totalSupply(), amount - tokensUnbonded);
    }

    function testBondingAndRedeemingWithNonWadAssets(bool redeemT1) public {
        //----------------------------------
        // Bonding

        // Asset 1:
        // price = 1e18 (1$), decimals = 20, balance = 1e20
        // => total value = 1$
        ERC20Mock t1;
        OracleMock o1;
        (t1, o1) = setUpForBonding(ONE_USD, 1e20, 20);

        // Bond t1.
        treasury.bondERC20(address(t1), 1e20);

        // Check that address(this) received amount of KTT tokens.
        assertEq(treasury.balanceOf(address(this)), 1e18);
        // Check that address(this) does not have any t1 anymore.
        assertEq(t1.balanceOf(address(this)), 0);
        // Check that treasury now holds the t1.
        assertEq(t1.balanceOf(address(treasury)), 1e20);
        // Check that treasury's total valuation equals the amount bonded.
        assertEq(treasury.totalValuation(), 1e18);
        // Check that KTT's total supply equals the treasury's valuation.
        assertEq(treasury.totalSupply(), 1e18);

        // Asset 2:
        // price = 2e18 (2$), decimals = 9, balance = 2e9
        // => total value = 4$
        ERC20Mock t2;
        OracleMock o2;
        (t2, o2) = setUpForBonding(ONE_USD * 2, 2e9, 9);

        // Bond t2.
        treasury.bondERC20(address(t2), 2e9);

        // Check that address(this) received amount of KTT tokens.
        assertEq(treasury.balanceOf(address(this)), 1e18 + (2e18 * 2));
        // Check that address(this) does not have any t2 anymore.
        assertEq(t2.balanceOf(address(this)), 0);
        // Check that treasury now holds the t2.
        assertEq(t2.balanceOf(address(treasury)), 2e9);
        // Check that treasury's total valuation equals the amount bonded.
        assertEq(treasury.totalValuation(), 1e18 + (2e18 * 2));
        // Check that KTT's total supply equals the treasury's valuation.
        assertEq(treasury.totalSupply(), 1e18 + (2e18 * 2));

        //----------------------------------
        // Redeeming
        // Note that we cannot unbond all tokens.
        // Therefore only redeem one of the two tokens.

        if (redeemT1) {
            // List t1 as redeemable.
            treasury.listERC20AsRedeemable(address(t1));

            // address(this) redeem t1.
            treasury.redeemERC20(address(t1), 1e18);

            // Check that address(this) received the t1 redeemed.
            assertEq(t1.balanceOf(address(this)), 1e20);
            // Check that address(this)'s KTT tokens got burned.
            assertEq(treasury.balanceOf(address(this)), 2e18 * 2);
            // Check that treasury's total valuation decreased by the amount of
            // tokens unbonded.
            assertEq(treasury.totalValuation(), 2e18 * 2);
            // Check that KTT's total supply equals the treasury's valuation.
            assertEq(treasury.totalSupply(), 2e18 * 2);
        } else {
            // Mark t2 as redeemable.
            treasury.listERC20AsRedeemable(address(t2));

            // address(this) redeem t2.
            treasury.redeemERC20(address(t2), 2e18 * 2);

            // Check that address(this) received the t1 redeemed.
            assertEq(t2.balanceOf(address(this)), 2e9);
            // Check that address(this)'s KTT tokens got burned.
            assertEq(treasury.balanceOf(address(this)), 1e18);
            // Check that treasury's total valuation decreased by the amount of
            // tokens unbonded.
            assertEq(treasury.totalValuation(), 1e18);
            // Check that KTT's total supply equals the treasury's valuation.
            assertEq(treasury.totalSupply(), 1e18);
        }
    }

}
