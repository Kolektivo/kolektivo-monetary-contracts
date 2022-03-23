// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";

/**
 * @dev onlyOwner Function Tests.
 */
contract TreasuryOnlyOwner is TreasuryTest {

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        if (caller == treasury.owner()) {
            return;
        }

        // We need to support one asset, otherwise functions can fail with
        // AssetIsNotSupported instead of OnlyCallableByOwner.
        // Note that the asset also needs a functioning oracle to be accepted
        //      as supported.
        address asset = address(1);
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        EVM.startPrank(caller);

        //----------------------------------
        // Emergency Functions

        bytes memory callData = bytes("");

        try treasury.executeTx(address(0), callData) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        //----------------------------------
        // Whitelist Management

        try treasury.addToWhitelist(address(1)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try treasury.removeFromWhitelist(address(1)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        //----------------------------------
        // Asset and Oracle Management

        try treasury.supportAsset(address(1), address(2)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try treasury.unsupportAsset(address(1)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try treasury.updateAssetOracle(asset, address(oracle)) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        //----------------------------------
        // Un/Bonding Management

        try treasury.supportAssetForBonding(asset) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try treasury.unsupportAssetForBonding(asset) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try treasury.supportAssetForUnbonding(asset) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

        try treasury.unsupportAssetForUnbonding(asset) {
            revert();
        } catch {
            // Fails with OnlyCallableByOwner.
        }

    }

    //----------------------------------
    // Emergency Functions

    function testExecuteTx() public {
        // Call a publicly callable function on the treasury.
        address target = address(treasury);
        bytes memory callData = abi.encodeWithSignature(
            "totalValuation()"
        );

        treasury.executeTx(target, callData);
    }

    function testFailExecuteTx() public {
        // Call an onlyOwner function on the treasury.
        address target = address(treasury);
        bytes memory callData = abi.encodeWithSignature(
            "addToWhitelist()",
            address(0)
        );

        treasury.executeTx(target, callData);
    }

    //----------------------------------
    // Whitelist Management

    function testAddToWhitelist(address who) public {
        treasury.addToWhitelist(who);
        // Function should be idempotent.
        treasury.addToWhitelist(who);

        // Check that address got whiteslited.
        assertTrue(treasury.whitelist(who));
    }

    function testRemoveFromWhitelist(address who) public {
        treasury.addToWhitelist(who);

        treasury.removeFromWhitelist(who);
        // Function should be idempotent.
        treasury.removeFromWhitelist(who);

        // Check that address is not whitelisted anymore.
        assertTrue(!treasury.whitelist(who));
    }

    //----------------------------------
    // Asset and Oracle Management

    function testSupportAsset(address asset) public {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        treasury.supportAsset(asset, address(oracle));
        // Function should be idempotent.
        treasury.supportAsset(asset, address(oracle));

        // Check that asset is supported.
        assertEq(treasury.supportedAssets(0), asset);

        // Check that asset's oracle is correct.
        assertEq(treasury.oraclePerAsset(asset), address(oracle));

        // Check that asset's last price was updated.
        assertEq(treasury.lastPricePerAsset(asset), 1);

        // Check that function is idempotent.
        try treasury.supportedAssets(1) {
            revert();
        } catch {
            // Fails due to IndexOutOfBounds.
        }
    }

    function testSupportAssetCanNotUpdateOracle(address asset) public {
        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);

        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(1, true);

        treasury.supportAsset(asset, address(oracle1));

        try treasury.supportAsset(asset, address(oracle2)) {
            revert();
        } catch {
            // Fails due to not being able to update oracle through the
            // supportAsset function.
        }
    }

    function testSupportAssetDoesNotAcceptInvalidOracle(address asset) public {
        OracleMock oracle = new OracleMock();

        // Set oracle as invalid but data as non-zero.
        oracle.setDataAndValid(1, false);
        try treasury.supportAsset(asset, address(oracle)) {
            revert();
        } catch {
            // Fails with StalePriceDeliveredByOracle.
        }

        // Set oracle as valid but data as zero.
        oracle.setDataAndValid(0, true);
        try treasury.supportAsset(asset, address(oracle)) {
            revert();
        } catch {
            // Fails with StalePriceDeliveredByOracle.
        }
    }

    function testUnsupportAsset(address asset) public {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        treasury.unsupportAsset(asset);
        // Function should be idempotent.
        treasury.unsupportAsset(asset);

        // Check that asset's oracle was removed.
        assertEq(treasury.oraclePerAsset(asset), address(0));

        // Check that asset's last price was removed.
        assertEq(treasury.lastPricePerAsset(asset), 0);

        // Check that asset is not supported anymore.
        try treasury.supportedAssets(0) {
            revert();
        } catch {
            // Fails due to IndexOutOfBounds.
        }
    }

    function testUpdateAssetOracle(address asset) public {
        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle1));

        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(2, true);
        treasury.updateAssetOracle(asset, address(oracle2));
        // Function should be idempotent.
        treasury.updateAssetOracle(asset, address(oracle2));

        // Check that asset's oracle was updated.
        assertEq(treasury.oraclePerAsset(asset), address(oracle2));

        // Check that asset's last price was updated.
        assertEq(treasury.lastPricePerAsset(asset), 2);

        // Check that invalid oracle is not accepted.
        oracle1.setDataAndValid(1, false);
        try treasury.updateAssetOracle(asset, address(oracle1)) {
            revert();
        } catch {
            // Fails with StalePriceDeliveredByOracle.
        }

        // Check that oracle data of zero is not accepted.
        oracle1.setDataAndValid(0, true);
        try treasury.updateAssetOracle(asset, address(oracle1)) {
            revert();
        } catch {
            // Fails with StalePriceDeliveredByOracle.
        }
    }

    //----------------------------------
    // Un/Bonding Management

    function testSupportAssetForBonding(address asset) public {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        // Check that asset is not supported for bonding.
        assertTrue(!treasury.isSupportedForBonding(asset));

        treasury.supportAssetForBonding(asset);
        // Function should be idempotent.
        treasury.supportAssetForBonding(asset);

        // Check that asset is supported for bonding.
        assertTrue(treasury.isSupportedForBonding(asset));
    }

    function testUnsupportAssetForBonding(address asset) public {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));
        treasury.supportAssetForBonding(asset);

        treasury.unsupportAssetForBonding(asset);
        // Function should be idempotent.
        treasury.unsupportAssetForBonding(asset);

        // Check that asset is not supported for bonding.
        assertTrue(!treasury.isSupportedForBonding(asset));
    }

    function testFailSupportAssetForBondingWhileAssetNotSupported(address asset)
        public
    {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotSupported.
        treasury.supportAssetForBonding(asset);
    }

    function testSupportAssetForUnbonding(address asset) public {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        // Check that asset is not supported for unbonding.
        assertTrue(!treasury.isSupportedForUnbonding(asset));

        treasury.supportAssetForUnbonding(asset);
        // Function should be idempotent.
        treasury.supportAssetForUnbonding(asset);

        // Check that asset is supported for unbonding.
        assertTrue(treasury.isSupportedForUnbonding(asset));
    }

    function testUnsupportAssetForUnbonding(address asset) public {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));
        treasury.supportAssetForUnbonding(asset);

        treasury.unsupportAssetForUnbonding(asset);
        // Function should be idempotent.
        treasury.unsupportAssetForUnbonding(asset);

        // Check that asset is not supported for unbonding.
        assertTrue(!treasury.isSupportedForUnbonding(asset));
    }

    function testFailSupportAssetForUnbondingWhileAssetNotSupported(address asset)
        public
    {
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotSupported.
        treasury.supportAssetForUnbonding(asset);
    }

}