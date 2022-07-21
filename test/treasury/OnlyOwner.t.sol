// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";

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
        // Note that the asset also needs a functional oracle to be accepted
        // as supported.
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        vm.startPrank(caller);

        //----------------------------------
        // Emergency Functions

        bytes memory callData = bytes("");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.executeTx(address(0), callData);

        //----------------------------------
        // Whitelist Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.addToWhitelist(address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.removeFromWhitelist(address(1));

        //----------------------------------
        // Asset and Oracle Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.withdrawAsset(address(1), address(2), 1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.supportAsset(address(1), address(2));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.unsupportAsset(address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.updateAssetOracle(asset, address(oracle));

        //----------------------------------
        // Un/Bonding Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.supportAssetForBonding(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.unsupportAssetForBonding(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.supportAssetForUnbonding(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.unsupportAssetForUnbonding(asset);
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

    function testFailExecuteOnlyOwnerTx() public {
        // Call an onlyOwner function on the treasury.
        address target = address(treasury);
        bytes memory callData = abi.encodeWithSignature(
            "addToWhitelist()",
            address(0)
        );

        // Fails with OnlyCallableByOwner.
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

    function testWithdrawAsset_FailsIf_InvalidAmount() public {
        vm.expectRevert(Errors.InvalidAmount);
        treasury.withdrawAsset(address(1), address(1), 0);
    }

    function testWithdrawAsset_FailsIf_InvalidRecipient() public {
        vm.expectRevert(Errors.InvalidRecipient);
        treasury.withdrawAsset(address(1), address(0), 1);
    }

    function testWithdrawAsset_FailsIf_CodeIsZero() public {
        vm.expectRevert(bytes("")); // Empty require statement
        treasury.withdrawAsset(address(0), address(1), 1);
    }

    function testWithdrawAsset(address recipient, uint amount) public {
        vm.assume(recipient != address(0) && recipient != address(treasury));
        vm.assume(amount != 0);

        ERC20Mock asset = new ERC20Mock("TOKEN", "TKN", uint8(18));
        asset.mint(address(treasury), amount);

        treasury.withdrawAsset(address(asset), recipient, amount);
    }

    function testSupportAsset() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetMarkedAsSupported(asset, address(oracle));

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

    function testSupportAssetCanNotUpdateOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

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

    function testSupportAssetDoesNotAcceptInvalidOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();

        // Set oracle as invalid but data as non-zero.
        oracle.setDataAndValid(1, false);

        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle))
        );
        treasury.supportAsset(asset, address(oracle));
    }

    function testSupportAssetDoesNotAcceptOraclePriceOfZero() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();

        // Set oracle as valid but data as zero.
        oracle.setDataAndValid(0, true);

        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle))
        );
        treasury.supportAsset(asset, address(oracle));
    }

    function testUnsupportAsset() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetMarkedAsUnsupported(asset);

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

    function testUpdateAssetOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle1));

        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(2, true);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetOracleUpdated(asset, address(oracle1), address(oracle2));

        treasury.updateAssetOracle(asset, address(oracle2));

        // Function should be idempotent.
        treasury.updateAssetOracle(asset, address(oracle2));

        // Check that asset's oracle was updated.
        assertEq(treasury.oraclePerAsset(asset), address(oracle2));

        // Check that asset's last price was updated.
        assertEq(treasury.lastPricePerAsset(asset), 2);
    }

    function testUpdateAssetOracleDoesNotAcceptInvalidOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        // Setup asset with first oracle.
        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle1));

        // Create second oracle being invalid but data non-zero.
        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(1, false);

        // Check that invalid oracle is not accepted.
        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle2))
        );
        treasury.updateAssetOracle(asset, address(oracle2));
    }

    function testUpdateAssetOracleDoesNotAcceptOraclePriceOfZero() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        // Setup asset with first oracle.
        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle1));

        // Create second oracle being vali but data zero.
        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(0, true);

        // Check that oracle data of zero is not accepted.
        oracle2.setDataAndValid(0, true);
        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle2))
        );
        treasury.updateAssetOracle(asset, address(oracle2));
    }

    //----------------------------------
    // Un/Bonding Management

    function testSupportAssetForBonding() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        // Check that asset is not supported for bonding.
        assertTrue(!treasury.isSupportedForBonding(asset));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetMarkedAsSupportedForBonding(asset);

        treasury.supportAssetForBonding(asset);

        // Function should be idempotent.
        treasury.supportAssetForBonding(asset);

        // Check that asset is supported for bonding.
        assertTrue(treasury.isSupportedForBonding(asset));
    }

    function testUnsupportAssetForBonding() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));
        treasury.supportAssetForBonding(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetMarkedAsUnsupportedForBonding(asset);

        treasury.unsupportAssetForBonding(asset);

        // Function should be idempotent.
        treasury.unsupportAssetForBonding(asset);

        // Check that asset is not supported for bonding.
        assertTrue(!treasury.isSupportedForBonding(asset));
    }

    function testFailSupportAssetForBondingWhileAssetNotSupported() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotSupported.
        treasury.supportAssetForBonding(asset);
    }

    function testSupportAssetForUnbonding() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));

        // Check that asset is not supported for unbonding.
        assertTrue(!treasury.isSupportedForUnbonding(asset));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetMarkedAsSupportedForUnbonding(asset);

        treasury.supportAssetForUnbonding(asset);

        // Function should be idempotent.
        treasury.supportAssetForUnbonding(asset);

        // Check that asset is supported for unbonding.
        assertTrue(treasury.isSupportedForUnbonding(asset));
    }

    function testUnsupportAssetForUnbonding() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.supportAsset(asset, address(oracle));
        treasury.supportAssetForUnbonding(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetMarkedAsUnsupportedForUnbonding(asset);

        treasury.unsupportAssetForUnbonding(asset);

        // Function should be idempotent.
        treasury.unsupportAssetForUnbonding(asset);

        // Check that asset is not supported for unbonding.
        assertTrue(!treasury.isSupportedForUnbonding(asset));
    }

    function testFailSupportAssetForUnbondingWhileAssetNotSupported() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotSupported.
        treasury.supportAssetForUnbonding(asset);
    }

}
