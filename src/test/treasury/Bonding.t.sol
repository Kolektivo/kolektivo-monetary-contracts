// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

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

    modifier validUser(address user, bool fail) {
        if (user != address(0) && user != address(this)) {
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
        address user,
        uint price,
        uint amount,
        uint decimals
    ) public returns (ERC20Mock, OracleMock) {
        // Create token and oracle.
        ERC20Mock token = new ERC20Mock("TKN", "Token", uint8(decimals));
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(price, true);

        // Let treasury support token for bonding.
        treasury.supportAsset(address(token), address(oracle));
        treasury.supportAssetForBonding(address(token));

        // Add user to whitelist and mint them tokens.
        treasury.addToWhitelist(user);
        token.mint(user, amount);

        // Approve user's tokens for treasury.
        vm.prank(user);
        token.approve(address(treasury), type(uint).max);

        return (token, oracle);
    }

    //--------------------------------------------------------------------------
    // Tests

    //----------------------------------
    // Un/Bonding disabled for invalid oracles

    function testFailBondingDisabledIfOracleInvalid(address user, uint amount)
        public
        validUser(user, true)
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(user, ONE_USD, amount, 18);

        // Set token's oracle to invalid.
        oracle.setValid(false);

        // Fails with StalePriceDeliveredByOracle.
        vm.prank(user);
        treasury.bond(address(token), amount);
    }

    function testFailBondingDisabledIfOraclePriceIsZero(address user, uint amount)
        public
        validUser(user, true)
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(user, ONE_USD, amount, 18);

        // Set token's oracle price to 0.
        oracle.setData(0);

        // Fails with StalePriceDeliveredByOracle.
        vm.prank(user);
        treasury.bond(address(token), amount);
    }

    function testFailUnbondingDisabledIfOracleInvalid(address user, uint amount)
        public
        validUser(user, true)
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(user, ONE_USD, amount, 18);

        // Mark token as unbondable.
        treasury.supportAssetForUnbonding(address(token));

        // Bond tokens.
        vm.prank(user);
        treasury.bond(address(token), amount);

        // Set token's oracle to invalid.
        oracle.setValid(false);

        // Fails with StalePriceDelivered.
        vm.prank(user);
        treasury.unbond(address(token), amount);
    }

    function testFailUnbondingDisabledIfOraclePriceIsZero(address user, uint amount)
        public
        validUser(user, true)
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(user, ONE_USD, amount, 18);

        // Mark token as unbondable.
        treasury.supportAssetForUnbonding(address(token));

        // Bond tokens.
        vm.prank(user);
        treasury.bond(address(token), amount);

        // Set oracle's price to zero.
        oracle.setData(0);

        // Fails with StalePriceDelivered.
        vm.prank(user);
        treasury.unbond(address(token), amount);
    }

    //----------------------------------
    // Bonding

    function testFailCanNotUnbondToZero(address user, uint amount)
        public
        validUser(user, true)
        validAmount(amount, true)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(user, ONE_USD, amount, 18);

        // Mark token as unbondable.
        treasury.supportAssetForUnbonding(address(token));

        // Bond tokens.
        vm.prank(user);
        treasury.bond(address(token), amount);

        // Unbond all tokens.
        vm.prank(user);
        // Fails with a Division by 0 in ElasticReceiptToken.
        treasury.unbond(address(token), amount);
    }

    function testBondingAndUnbonding(address user, uint amount)
        public
        validUser(user, false)
        validAmount(amount, false)
    {
        ERC20Mock token;
        OracleMock oracle;
        (token, oracle) = setUpForBonding(user, ONE_USD, amount, 18);

        // Mark token as unbondable.
        treasury.supportAssetForUnbonding(address(token));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetsBonded(user, address(token), amount);

        // Bond tokens.
        vm.prank(user);
        treasury.bond(address(token), amount);

        // Check that user received amount of KTT tokens.
        assertEq(treasury.balanceOf(user), amount);
        // Check that user does not have any tokens anymore.
        assertEq(token.balanceOf(user), 0);
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
        emit AssetsUnbonded(user, address(token), tokensUnbonded);

        vm.prank(user);
        treasury.unbond(address(token), tokensUnbonded);

        // Check that user received the tokens unbonded.
        assertEq(token.balanceOf(user), tokensUnbonded);
        // Check that user's KTT tokens got burned.
        assertEq(treasury.balanceOf(user), amount - tokensUnbonded);
        // Check that treasury's total valuation decreased by the amount of
        // tokens unbonded.
        assertEq(treasury.totalValuation(), amount - tokensUnbonded);
        // Check that KTT's total supply equals the treasury's valuation.
        assertEq(treasury.totalSupply(), amount - tokensUnbonded);
    }

    function testBondingAndUnbondingWithNonWadAssets(address user, bool unbondT1)
        public
        validUser(user, false)
    {
        //----------------------------------
        // Bonding

        // Asset 1:
        // price = 1e18 (1$), decimals = 20, balance = 1e20
        // => total value = 1$
        ERC20Mock t1;
        OracleMock o1;
        (t1, o1) = setUpForBonding(user, ONE_USD, 1e20, 20);

        // Bond t1.
        vm.prank(user);
        treasury.bond(address(t1), 1e20);

        // Check that user received amount of KTT tokens.
        assertEq(treasury.balanceOf(user), 1e18);
        // Check that user does not have any t1 anymore.
        assertEq(t1.balanceOf(user), 0);
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
        (t2, o2) = setUpForBonding(user, ONE_USD * 2, 2e9, 9);

        // Bond t2.
        vm.prank(user);
        treasury.bond(address(t2), 2e9);

        // Check that user received amount of KTT tokens.
        assertEq(treasury.balanceOf(user), 1e18 + (2e18 * 2));
        // Check that user does not have any t2 anymore.
        assertEq(t2.balanceOf(user), 0);
        // Check that treasury now holds the t2.
        assertEq(t2.balanceOf(address(treasury)), 2e9);
        // Check that treasury's total valuation equals the amount bonded.
        assertEq(treasury.totalValuation(), 1e18 + (2e18 * 2));
        // Check that KTT's total supply equals the treasury's valuation.
        assertEq(treasury.totalSupply(), 1e18 + (2e18 * 2));

        //----------------------------------
        // Unbonding
        // Note that we cannot unbond all tokens.
        // Therefore only unbond one of the two tokens.

        if (unbondT1) {
            // Mark t1 as unbondable.
            treasury.supportAssetForUnbonding(address(t1));

            // User unbonds t1.
            vm.prank(user);
            treasury.unbond(address(t1), 1e18);

            // Check that user received the t1 unbonded.
            assertEq(t1.balanceOf(user), 1e20);
            // Check that user's KTT tokens got burned.
            assertEq(treasury.balanceOf(user), 2e18 * 2);
            // Check that treasury's total valuation decreased by the amount of
            // tokens unbonded.
            assertEq(treasury.totalValuation(), 2e18 * 2);
            // Check that KTT's total supply equals the treasury's valuation.
            assertEq(treasury.totalSupply(), 2e18 * 2);
        } else {
            // Mark t2 as unbondable.
            treasury.supportAssetForUnbonding(address(t2));

            // User unbonds t2.
            vm.prank(user);
            treasury.unbond(address(t2), 2e18 * 2);

            // Check that user received the t1 unbonded.
            assertEq(t2.balanceOf(user), 2e9);
            // Check that user's KTT tokens got burned.
            assertEq(treasury.balanceOf(user), 1e18);
            // Check that treasury's total valuation decreased by the amount of
            // tokens unbonded.
            assertEq(treasury.totalValuation(), 1e18);
            // Check that KTT's total supply equals the treasury's valuation.
            assertEq(treasury.totalSupply(), 1e18);
        }
    }

}
