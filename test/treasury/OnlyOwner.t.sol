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

        // We need to register one asset, otherwise functions can fail with
        // AssetIsNotRegistered instead of OnlyCallableByOwner.
        // Note that the asset also needs a functional oracle to be accepted
        // as supported.
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));
        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle));

        // List asset as bondable + redeemable.
        treasury.listAssetAsBondable(asset);
        treasury.listAssetAsRedeemable(asset);

        vm.startPrank(caller);

        //----------------------------------
        // Emergency Functions

        bytes memory callData = bytes("");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.executeTx(address(0), callData);

        //----------------------------------
        // Bond & Redeem Function

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.bond(asset, 1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.redeem(asset, 1);

        //----------------------------------
        // Asset and Oracle Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.withdrawAsset(address(1), address(2), 1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.registerAsset(address(1), address(2));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.deregisterAsset(address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.updateAssetOracle(asset, address(oracle));

        //----------------------------------
        // Un/Bonding Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.listAssetAsBondable(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.delistAssetAsBondable(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.listAssetAsRedeemable(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.delistAssetAsRedeemable(asset);
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
            "listAssetAsBondable()",
            address(0)
        );

        // Fails with OnlyCallableByOwner.
        treasury.executeTx(target, callData);
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

        vm.expectRevert(Errors.InvalidRecipient);
        treasury.withdrawAsset(address(1), address(treasury), 1);
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
        assertEq(asset.balanceOf(address(treasury)), 0);
        assertEq(asset.balanceOf(address(recipient)), amount);
    }

    function testRegisterAsset() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetRegistered(asset, address(oracle));

        treasury.registerAsset(asset, address(oracle));

        // Function should be idempotent.
        treasury.registerAsset(asset, address(oracle));

        // Check that asset is supported.
        assertEq(treasury.registeredAssets(0), asset);

        // Check that asset's oracle is correct.
        assertEq(treasury.oraclePerAsset(asset), address(oracle));

        // Check that function is idempotent.
        try treasury.registeredAssets(1) {
            revert();
        } catch {
            // Fails due to IndexOutOfBounds.
        }
    }

    function testRegisterAssetCanNotUpdateOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);

        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(1, true);

        treasury.registerAsset(asset, address(oracle1));

        try treasury.registerAsset(asset, address(oracle2)) {
            revert();
        } catch {
            // Fails due to not being able to update oracle through the
            // supportAsset function.
        }
    }

    function testRegisterAssetDoesNotAcceptInvalidOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();

        // Set oracle as invalid but data as non-zero.
        oracle.setDataAndValid(1, false);

        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle))
        );
        treasury.registerAsset(asset, address(oracle));
    }

    function testRegisterAssetDoesNotAcceptOraclePriceOfZero() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();

        // Set oracle as valid but data as zero.
        oracle.setDataAndValid(0, true);

        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle))
        );
        treasury.registerAsset(asset, address(oracle));
    }

    function testDeregisterAsset() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetDeregistered(asset);

        treasury.deregisterAsset(asset);

        // Function should be idempotent.
        treasury.deregisterAsset(asset);

        // Check that asset's oracle was removed.
        assertEq(treasury.oraclePerAsset(asset), address(0));

        // Check that asset is not supported anymore.
        try treasury.registeredAssets(0) {
            revert();
        } catch {
            // Fails due to IndexOutOfBounds.
        }
    }

    function testUpdateAssetOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle1));

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
    }

    function testUpdateAssetOracleDoesNotAcceptInvalidOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        // Setup asset with first oracle.
        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle1));

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
        treasury.registerAsset(asset, address(oracle1));

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

    function testListAssetAsBondable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle));

        // Check that asset is not listed as bondable.
        assertTrue(!treasury.isAssetBondable(asset));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetListedAsBondable(asset);

        treasury.listAssetAsBondable(asset);

        // Function should be idempotent.
        treasury.listAssetAsBondable(asset);

        // Check that asset is listed as bondable.
        assertTrue(treasury.isAssetBondable(asset));
    }

    function testDelistAssetAsBondable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle));
        treasury.listAssetAsBondable(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetDelistedAsBondable(asset);

        treasury.delistAssetAsBondable(asset);

        // Function should be idempotent.
        treasury.delistAssetAsBondable(asset);

        // Check that asset is not supported for bonding.
        assertTrue(!treasury.isAssetBondable(asset));
    }

    function testFailListAssetAsBondableWhileAssetNotRegistered() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotRegistered.
        treasury.listAssetAsBondable(asset);
    }

    function testListAssetAsRedeemable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle));

        // Check that asset is not listes as redeemable.
        assertTrue(!treasury.isAssetRedeemable(asset));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetListedAsRedeemable(asset);

        treasury.listAssetAsRedeemable(asset);

        // Function should be idempotent.
        treasury.listAssetAsRedeemable(asset);

        // Check that asset is supported for unbonding.
        assertTrue(treasury.isAssetRedeemable(asset));
    }

    function testDelistAssetAsRedeemable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerAsset(asset, address(oracle));
        treasury.listAssetAsRedeemable(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit AssetDelistedAsRedeemable(asset);

        treasury.delistAssetAsRedeemable(asset);

        // Function should be idempotent.
        treasury.delistAssetAsRedeemable(asset);

        // Check that asset is not supported for unbonding.
        assertTrue(!treasury.isAssetRedeemable(asset));
    }

    function testFailListAssetAsRedeemableWhileAssetNotRegistered() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotRegistered.
        treasury.listAssetAsRedeemable(asset);
    }

}
