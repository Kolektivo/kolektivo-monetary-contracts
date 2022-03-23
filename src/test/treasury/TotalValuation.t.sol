// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";

/**
 * @dev Tests the Calculation of the Treasury's Total Valuation.
 */
contract TreasuryTotalValuation is TreasuryTest {

    // The max amount of assets the treasury should hold for the purpose of
    // this tests.
    uint private constant MAX_ASSETS = 27;

    // An asset with corresponding oracle, price and treasury's balance.
    struct Asset {
        ERC20Mock asset;
        OracleMock oracle;
        uint price;
        uint balance;
    }

    Asset[] assets;

    function testTotalValuation(uint assetAmount) public {
        assetAmount %= MAX_ASSETS;
        if (assetAmount == 0) {
            return;
        }

        uint want = setUpAssets(assetAmount);
        uint got = treasury.totalValuation();
        assertEq(got, want);
    }

    function setUpAssets(uint amount) public returns (uint) {
        uint totalValuation;

        for (uint i; i < amount; i++) {
            // Get "random" values for price and balance.
            // Make sure that price is never zero.
            uint price = (amount % (i+1)) + 1;
            uint balance = amount % (i+1);

            // @todo Only 18 decimals supported.
            price *= 1e18;
            balance *= 1e18;

            // @todo Only 18 decimals supported.
            if (balance != 0) {
                totalValuation += (price * balance) / 1e18;
            }

            // Return early if KTTs MAX_SUPPLY reached.
            if (totalValuation > MAX_SUPPLY) {
                return totalValuation;
            }

            // Setup token and oracle.
            OracleMock oracle = new OracleMock();
            oracle.setDataAndValid(price, true);
            ERC20Mock token = new ERC20Mock("TST", "TEST", uint8(18));

            // Support token by treasury and mint balance.
            treasury.supportAsset(address(token), address(oracle));
            token.mint(address(treasury), balance);

            // Add asset to array.
            assets.push(Asset(token, oracle, price, balance));
        }

        return totalValuation;
    }

}
