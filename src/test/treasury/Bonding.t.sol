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

    /*
    function testBondingAndUnbondingWithAssetsUsingDifferentPrecision() public {
        address user = address(1);
        uint amount = 1e18;
        uint[2] memory decimals = [uint(9), 25];

        for (uint i; i < decimals.length; i++) {
            uint decimal = decimals[i];

            // Calculate the USD amount the amount represents.
            uint usdAmount =
                18 >= decimal
                    // If token uses less decimals, move by diff of decimals
                    // to the left.
                    ? amount * 10**(18-decimal)
                    // If token uses more decimals, move by diff of decimals
                    // to the right.
                    : amount / 10**(decimal-18);

            ERC20Mock token;
            OracleMock oracle;
            (token, oracle) = setUpForBonding(
                user,
                ONE_USD,
                amount,
                decimals[i]
            );

            // Mark token as unbondable.
            treasury.supportAssetForUnbonding(address(token));

            // Bond tokens.
            vm.prank(user);
            treasury.bond(address(token), amount);

            // Check that user received amount of KTT tokens.
            assertEq(treasury.balanceOf(user), usdAmount);
            // Check that user does not have any tokens anymore.
            assertEq(token.balanceOf(user), 0);
            // Check that treasury now holds the tokens.
            assertEq(token.balanceOf(address(treasury)), amount);
            // Check that treasury's total valuation equals the amount bonded.
            assertEq(treasury.totalValuation(), usdAmount);
            // Check that KTT's total supply equals the treasury's valuation.
            assertEq(treasury.totalSupply(), usdAmount);

            // Note that not all assets can be unbonded.
            usdAmount--;
            uint tokenNotWithdrawed =
                18 >= decimal
                    ? usdAmount / 10**(18-decimal)
                    : usdAmount * 10**(decimal-18);

            // Expect event emission.
            vm.expectEmit(true, true, true, true);
            emit AssetsUnbonded(user, address(token), usdAmount);

            vm.prank(user);
            treasury.unbond(address(token), usdAmount);

            // Check that user received the tokens unbonded.
            assertEq(token.balanceOf(user), amount);
            // Check that user's KTT tokens got burned.
            assertEq(treasury.balanceOf(user), tokenNotWithdrawed);
            // Check that treasury's total valuation decreased by the amount of
            // tokens unbonded.
            assertEq(treasury.totalValuation(), tokenNotWithdrawed);
            // Check that KTT's total supply equals the treasury's valuation.
            assertEq(treasury.totalSupply(), tokenNotWithdrawed);
        }
    }
    */

}
