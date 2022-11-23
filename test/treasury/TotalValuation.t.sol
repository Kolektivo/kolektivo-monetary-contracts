// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

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

    function testTotalValuationWithWadAssets(uint assetAmount) public {
        assetAmount %= MAX_ASSETS;
        if (assetAmount == 0) {
            return;
        }

        uint want = setUpWadAssets(assetAmount);
        uint got = treasury.totalValuation();
        assertEq(got, want);
    }

    function testTotalValuationWithNonWadAssets()
        public
    {
        // Asset 1:
        // price = 1e18, decimals = 20, balance = 1e20
        // => valuation = 1$
        OracleMock o1 = new OracleMock();
        o1.setDataAndValid(1e18, true);
        ERC20Mock t1 = new ERC20Mock("T1", "Token 1", uint8(20));
        treasury.registerERC20(address(t1), address(o1), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
        t1.mint(address(treasury), 1e20); // 1 USD

        // Asset 2:
        // price = 2e18, decimals = 5, balance = 1e5
        // => valuation = 2$
        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(2e18, true);
        ERC20Mock t2 = new ERC20Mock("T2", "Token 2", uint8(5));
        treasury.registerERC20(address(t2), address(o2), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
        t2.mint(address(treasury), 1e5); // 2 USD

        assertEq(treasury.totalValuation(), 3e18);
    }

    //--------------------------------------------------------------------------
    // Helper

    function setUpWadAssets(uint amount) private returns (uint) {
        uint totalValuation;

        for (uint i; i < amount; i++) {
            // Get "random" values for price and balance.
            // Note to make sure that price is never zero.
            uint price = (amount % (i+1)) + 1;
            uint balance = amount % (i+1);

            price *= 1e18;
            balance *= 1e18;

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

            // Register token and mint balance.
            treasury.registerERC20(address(token), address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
            token.mint(address(treasury), balance);

            // Add asset to array.
            assets.push(Asset(token, oracle, price, balance));
        }

        return totalValuation;
    }

}
