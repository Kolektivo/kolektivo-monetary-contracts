// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

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
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // List asset as bondable + redeemable.
        treasury.listERC20AsBondable(asset);
        treasury.listERC20AsRedeemable(asset);

        vm.startPrank(caller);

        //----------------------------------
        // Emergency Functions

        bytes memory callData = bytes("");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.executeTx(address(0), callData);

        //----------------------------------
        // Bond & Redeem Function

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.bondERC20(asset, 1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.redeemERC20(asset, 1);

        //----------------------------------
        // Asset and Oracle Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.withdrawERC20(address(1), address(2), 1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.registerERC20(address(1), address(2), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.deregisterERC20(address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.updateERC20Oracle(asset, address(oracle));

        //----------------------------------
        // Un/Bonding Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.listERC20AsBondable(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.delistERC20AsBondable(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.listERC20AsRedeemable(asset);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        treasury.delistERC20AsRedeemable(asset);
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
            "listERC20AsBondable()",
            address(0)
        );

        // Fails with OnlyCallableByOwner.
        treasury.executeTx(target, callData);
    }

    //----------------------------------
    // Asset and Oracle Management

    function testWithdrawAsset_FailsIf_InvalidAmount() public {
        vm.expectRevert(Errors.InvalidAmount);
        treasury.withdrawERC20(address(1), address(1), 0);
    }

    function testWithdrawAsset_FailsIf_InvalidRecipient() public {
        vm.expectRevert(Errors.InvalidRecipient);
        treasury.withdrawERC20(address(1), address(0), 1);

        vm.expectRevert(Errors.InvalidRecipient);
        treasury.withdrawERC20(address(1), address(treasury), 1);
    }

    function testWithdrawAsset_FailsIf_CodeIsZero() public {
        vm.expectRevert(bytes("")); // Empty require statement
        treasury.withdrawERC20(address(0), address(1), 1);
    }

    function testWithdrawAsset(address recipient, uint amount) public {
        vm.assume(recipient != address(0) && recipient != address(treasury));
        vm.assume(amount != 0);

        ERC20Mock asset = new ERC20Mock("TOKEN", "TKN", uint8(18));
        asset.mint(address(treasury), amount);

        treasury.withdrawERC20(address(asset), recipient, amount);
        assertEq(asset.balanceOf(address(treasury)), 0);
        assertEq(asset.balanceOf(address(recipient)), amount);
    }

    function testRegisterAsset() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20Registered(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // Function should be idempotent.
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // Check that asset is supported.
        assertEq(treasury.registeredERC20s(0), asset);

        // Check that asset type is set correctly
        assertEq(uint(treasury.assetTypeOfERC20(asset)), uint(Treasury.AssetType.Default));

        // Check that asset's oracle is correct.
        assertEq(treasury.oraclePerERC20(asset), address(oracle));

        // Check that function is idempotent.
        try treasury.registeredERC20s(1) {
            revert();
        } catch {
            // Fails due to IndexOutOfBounds.
        }
        
        // Deregister asset
        treasury.deregisterERC20(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20Registered(asset, address(oracle), Treasury.AssetType.Stable, Treasury.RiskLevel.Medium);

        // Register asset with different asset type
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Stable, Treasury.RiskLevel.Medium);

        // Check that asset type is set correctly
        assertEq(uint(treasury.assetTypeOfERC20(asset)), uint(Treasury.AssetType.Stable));

        // Check that the risk level is set correctly
        assertEq(uint(treasury.riskLevelOfERC20(asset)), uint(Treasury.RiskLevel.Medium));

        treasury.deregisterERC20(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20Registered(asset, address(oracle), Treasury.AssetType.Ecological, Treasury.RiskLevel.High);
        
        // Register asset with different asset type
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Ecological, Treasury.RiskLevel.High);

        // Check that asset type is set correctly
        assertEq(uint(treasury.assetTypeOfERC20(asset)), uint(Treasury.AssetType.Ecological));

        // Check that the risk level is set correctly
        assertEq(uint(treasury.riskLevelOfERC20(asset)), uint(Treasury.RiskLevel.High));
    }

     function testRegisterAssetWithTypeAndRiskLevel(uint assetType, uint riskLevel) public {
        vm.assume(assetType <= uint(type(Treasury.AssetType).max));
        vm.assume(riskLevel <= uint(type(Treasury.RiskLevel).max));

        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20Registered(asset, address(oracle), Treasury.AssetType(assetType), Treasury.RiskLevel(riskLevel));

        treasury.registerERC20(asset, address(oracle), Treasury.AssetType(assetType), Treasury.RiskLevel(riskLevel));

        // Check that asset is supported.
        assertEq(treasury.registeredERC20s(0), asset);

        // Check that asset type is set correctly
        assertEq(uint(treasury.assetTypeOfERC20(asset)), assetType);

        // Check that the risk level is set correctly
        assertEq(uint(treasury.riskLevelOfERC20(asset)), riskLevel);
    }

    

    function testRegisterAssetCanNotUpdateOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);

        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(1, true);

        treasury.registerERC20(asset, address(oracle1), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        try treasury.registerERC20(asset, address(oracle2), Treasury.AssetType.Default, Treasury.RiskLevel.Low) {
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
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
    }

    function testRegisterAssetDoesNotAcceptOraclePriceOfZero() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();

        // Set oracle as valid but data as zero.
        oracle.setDataAndValid(0, true);

        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle))
        );
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
    }

    function testDeregisterERC20() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20Deregistered(asset);

        treasury.deregisterERC20(asset);

        // Function should be idempotent.
        treasury.deregisterERC20(asset);

        // Check that asset's oracle was removed.
        assertEq(treasury.oraclePerERC20(asset), address(0));

        // Check that asset is not supported anymore.
        try treasury.registeredERC20s(0) {
            revert();
        } catch {
            // Fails due to IndexOutOfBounds.
        }
    }

    function testUpdateAssetOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle1), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(2, true);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20OracleUpdated(asset, address(oracle1), address(oracle2));

        treasury.updateERC20Oracle(asset, address(oracle2));

        // Function should be idempotent.
        treasury.updateERC20Oracle(asset, address(oracle2));

        // Check that asset's oracle was updated.
        assertEq(treasury.oraclePerERC20(asset), address(oracle2));
    }

    function testUpdateAssetOracleDoesNotAcceptInvalidOracle() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        // Setup asset with first oracle.
        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle1), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // Create second oracle being invalid but data non-zero.
        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(1, false);

        // Check that invalid oracle is not accepted.
        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle2))
        );
        treasury.updateERC20Oracle(asset, address(oracle2));
    }

    function testUpdateAssetOracleDoesNotAcceptOraclePriceOfZero() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        // Setup asset with first oracle.
        OracleMock oracle1 = new OracleMock();
        oracle1.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle1), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // Create second oracle being vali but data zero.
        OracleMock oracle2 = new OracleMock();
        oracle2.setDataAndValid(0, true);

        // Check that oracle data of zero is not accepted.
        oracle2.setDataAndValid(0, true);
        vm.expectRevert(
            Errors.StalePriceDeliveredByOracle(asset, address(oracle2))
        );
        treasury.updateERC20Oracle(asset, address(oracle2));
    }

    //----------------------------------
    // Un/Bonding Management

    function testListAssetAsBondable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // Check that asset is not listed as bondable.
        assertTrue(!treasury.isERC20Bondable(asset));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20ListedAsBondable(asset);

        treasury.listERC20AsBondable(asset);

        // Function should be idempotent.
        treasury.listERC20AsBondable(asset);

        // Check that asset is listed as bondable.
        assertTrue(treasury.isERC20Bondable(asset));
    }

    function testDelistERC20AsBondable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
        treasury.listERC20AsBondable(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20DelistedAsBondable(asset);

        treasury.delistERC20AsBondable(asset);

        // Function should be idempotent.
        treasury.delistERC20AsBondable(asset);

        // Check that asset is not supported for bonding.
        assertTrue(!treasury.isERC20Bondable(asset));
    }

    function testFailListAssetAsBondableWhileAssetNotRegistered() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotRegistered.
        treasury.listERC20AsBondable(asset);
    }

    function testListAssetAsRedeemable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);

        // Check that asset is not listes as redeemable.
        assertTrue(!treasury.isERC20Redeemable(asset));

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20ListedAsRedeemable(asset);

        treasury.listERC20AsRedeemable(asset);

        // Function should be idempotent.
        treasury.listERC20AsRedeemable(asset);

        // Check that asset is supported for unbonding.
        assertTrue(treasury.isERC20Redeemable(asset));
    }

    function testDelistERC20AsRedeemable() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);
        treasury.registerERC20(asset, address(oracle), Treasury.AssetType.Default, Treasury.RiskLevel.Low);
        treasury.listERC20AsRedeemable(asset);

        // Expect event emission.
        vm.expectEmit(true, true, true, true);
        emit ERC20DelistedAsRedeemable(asset);

        treasury.delistERC20AsRedeemable(asset);

        // Function should be idempotent.
        treasury.delistERC20AsRedeemable(asset);

        // Check that asset is not supported for unbonding.
        assertTrue(!treasury.isERC20Redeemable(asset));
    }

    function testFailListAssetAsRedeemableWhileAssetNotRegistered() public {
        address asset = address(new ERC20Mock("TOKEN", "TKN", uint8(18)));

        OracleMock oracle = new OracleMock();
        oracle.setDataAndValid(1, true);

        // Fails with AssetIsNotRegistered.
        treasury.listERC20AsRedeemable(asset);
    }

}
