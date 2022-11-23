// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./Test.t.sol";

contract ReserveOnlyOwner is ReserveTest {

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != reserve.owner());

        vm.startPrank(caller);

        address erc721 = address(1);

        //----------------------------------
        // Bond Functions

        //--------------
        // Bond ERC20 Functions

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC20(address(0), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC20From(address(0), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC20To(address(0), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC20FromTo(address(0), address(1), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC20All(address(0));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC20AllFrom(address(0), address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC20AllFromTo(address(0), address(1), address(1));

        //--------------
        // Bond ERC721Id Functions

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC721Id(address(erc721), DEFAULT_ERC721_ID);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC721IdFrom(address(erc721), DEFAULT_ERC721_ID, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC721IdTo(address(erc721), DEFAULT_ERC721_ID, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC721IdFromTo(address(erc721), DEFAULT_ERC721_ID, address(1), address(1));

        //----------------------------------
        // Redeem Functions

        //--------------
        // Redeem ERC20 Functions

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20(address(0), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20From(address(0), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20To(address(0), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20FromTo(address(0), address(1), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20All(address(0));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20AllFrom(address(0), address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20AllTo(address(0), address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC20AllFromTo(address(0), address(1), address(1));

        //--------------
        // redeem ERC721Id Functions

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC721Id(address(erc721), DEFAULT_ERC721_ID);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC721IdFrom(address(erc721), DEFAULT_ERC721_ID, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC721IdTo(address(erc721), DEFAULT_ERC721_ID, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.redeemERC721IdFromTo(address(erc721), DEFAULT_ERC721_ID, address(1), address(1));

        //----------------------------------
        // Emergency Functions

        bytes memory data = bytes("");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.executeTx(address(this), data);

        //----------------------------------
        // Token Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setTokenOracle(address(tokenOracle));

        //----------------------------------
        // Asset Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.registerERC20(address(token), address(tokenOracle), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.registerERC721Id(
            DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID,
            address(defaultERC721IdOracle)
        );

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.deregisterERC20(address(token));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.deregisterERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.updateOracleForERC20(address(token), address(tokenOracle));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.updateOracleForERC721Id(
            DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID,
            address(defaultERC721IdOracle)
        );

        //----------------------------------
        // Bonding & Redeeming Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.listERC20AsBondable(address(token));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.listERC721IdAsBondable(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.listERC20AsRedeemable(address(token));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.listERC721IdAsRedeemable(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setERC20BondingLimit(address(token), 1e18);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setERC20RedeemLimit(address(token), 1e18);

        //----------------------------------
        // Discount Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setBondingDiscountForERC20(address(token), 1e18);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setBondingDiscountForERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID, 1e18);

        //----------------------------------
        // Vesting Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setVestingVault(address(vestingVault));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setBondingVestingForERC20(address(token), 1 hours);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setBondingVestingForERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID, 1 hours);

        //---------------------------------
        // Reserve Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setMinBacking(1e18);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.withdrawERC20(address(1), address(1), 1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.withdrawERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.incurDebt(1e18);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.payDebt(1e18);
    }

    //----------------------------------
    // Emergency Functions

    function testExecuteTx() public {
        // Call a public callable function on the reserve2.
        address target = address(reserve);
        bytes memory data = abi.encodeWithSignature(
            "token()"
        );

        reserve.executeTx(target, data);
    }

    //----------------------------------
    // Token Management

    function testSetTokenOracle() public {
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        // @todo Test: Check event emission
        reserve.setTokenOracle(address(o));

        assertEq(reserve.tokenOracle(), address(o));
    }

    function testSetTokenOracle_NotAcceptedIfInvalid() public {
        // Invalid oracle is not accepted.
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, false);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.setTokenOracle(address(o));

        // Oracle delivering price of zero is not accepted.
        o.setDataAndValid(0, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.setTokenOracle(address(o));
    }

    //----------------------------------
    // Asset Management

    function testRegisterERC20() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        // @todo Check event emission.
        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);
        assertEq(reserve.registeredERC20s(0), address(erc20));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o));

        // Check that function is idempotent.
        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);
        assertEq(reserve.registeredERC20s(0), address(erc20));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o));

        // Reverts due to IndexOutOfBounds.
        // This indicates that the erc20 was not added again, i.e. that the
        // function is idempotent.
        vm.expectRevert(bytes(""));
        reserve.registeredERC20s(1);
    }

    function testRegisterERC20WithAssetType(uint assetType) public {
        vm.assume(assetType <= 2);

        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        // @todo Check event emission.
        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType(assetType), IReserve.RiskLevel.Low);
        assertEq(reserve.registeredERC20s(0), address(erc20));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o));

        // Check that asset type is set correctly
        assertEq(uint(reserve.assetTypeOfERC20(address(erc20))), assetType);
    }

    function testRegisterERC20_NotAcceptedIf_TokenCodeIsZero() public {
        address erc20 = address(0); // erc20 has no code

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC20(erc20, address(0), IReserve.AssetType.Default, IReserve.RiskLevel.Low);
    }

    function testRegisterERC20_NotAcceptedIf_AlreadyRegistered() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        // Reverts if erc20 is added again with a different oracle.
        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC20(address(erc20), address(o2), IReserve.AssetType.Default, IReserve.RiskLevel.Low);
    }

    function testRegisterERC20_NotAcceptedIf_OracleInvalid() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, false); // Oracle is invalid

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        o.setDataAndValid(0, true); // Oracle's price is zero

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);
    }

    function testRegisterERC721() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        // @todo Check event emission
        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        (address addedERC721, uint addedId) = reserve.registeredERC721Ids(0);
        assertEq(addedERC721, address(erc721));
        assertEq(addedId, DEFAULT_ERC721_ID);
        assertEq(reserve.oraclePerERC721Id(address(erc721), DEFAULT_ERC721_ID), address(o));

        // Check that function is idempotent.
        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        (addedERC721, addedId) = reserve.registeredERC721Ids(0);
        assertEq(addedERC721, address(erc721));
        assertEq(addedId, DEFAULT_ERC721_ID);
        assertEq(reserve.oraclePerERC721Id(address(erc721), DEFAULT_ERC721_ID), address(o));

        // Reverts due to IndexOutOfBounds.
        // This indicates that the erc721Id was not added again, i.e. that the
        // function is idempotent.
        vm.expectRevert(bytes(""));
        reserve.registeredERC721Ids(1);
    }

    function testRegisterERC721_NotAcceptedIf_TokenCodeIsZero() public {
        address erc721 = address(0); // ERC721 code is empty

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC721Id(erc721, DEFAULT_ERC721_ID, address(o));
    }

    function testRegisterERC721_NotAcceptedIf_AlreadyRegistered() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        // Reverts is ERC721Id is added again with different oracle.
        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o2));
    }

    function testRegisterERC721_NotAcceptedIf_OracleInvalid() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, false); // Oracle is invalid

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        o.setDataAndValid(0, true); // Oracle's price is zero

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));
    }

    function testDeregisterERC20() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        // @todo Check event emission.
        reserve.deregisterERC20(address(erc20));

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registeredERC20s(0);
        assertEq(reserve.oraclePerERC20(address(erc20)), address(0));

        // Check that function is idempotent.
        reserve.deregisterERC20(address(erc20));

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registeredERC20s(0);
        assertEq(reserve.oraclePerERC20(address(erc20)), address(0));
    }

    function testDeregisterERC721Id() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        // @todo Check event emission
        reserve.deregisterERC721Id(address(erc721), DEFAULT_ERC721_ID);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registeredERC721Ids(0);
        assertEq(reserve.oraclePerERC721Id(address(erc721), DEFAULT_ERC721_ID), address(0));

        // Check that function is idempotent.
        reserve.deregisterERC721Id(address(erc721), DEFAULT_ERC721_ID);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.registeredERC721Ids(0);
        assertEq(reserve.oraclePerERC721Id(address(erc721), DEFAULT_ERC721_ID), address(0));
    }

    function testUpdateOracleForERC20() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        // @todo Check event emission.
        reserve.updateOracleForERC20(address(erc20), address(o2));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o2));

        // Check that function is idempotent.
        reserve.updateOracleForERC20(address(erc20), address(o2));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o2));
    }

    function testUpdateOracleForERC20_NotAcceptedIf_ERC20NotRegistered()
        public
    {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC20NotRegistered);
        reserve.updateOracleForERC20(address(erc20), address(o));
    }

    function testUpdateOracleForERC20_NotAcceptedIf_OracleInvalid() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, false); // Oracle is invalid

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.updateOracleForERC20(address(erc20), address(o2));

        o2.setDataAndValid(0, true); // Oracle's price is zero

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.updateOracleForERC20(address(erc20), address(o2));
    }

    function testUpdateOracleForERC721Id() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        // @todo Check event emission.
        reserve.updateOracleForERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o2));
        assertEq(reserve.oraclePerERC721Id(address(erc721), DEFAULT_ERC721_ID), address(o2));

        // Check that function is idempotent.
        reserve.updateOracleForERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o2));
        assertEq(reserve.oraclePerERC721Id(address(erc721), DEFAULT_ERC721_ID), address(o2));
    }

    function testUpdateOracleForERC721Id_NotAcceptedIf_ERC721IdNotRegistered()
        public
    {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC721IdNotRegistered);
        reserve.updateOracleForERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));
    }

    function testUpdateOracleForERC721Id_NotAcceptedIf_OracleInvalid() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, false); // Oracle is invalid

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.updateOracleForERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o2));

        o2.setDataAndValid(0, true); // Oracle's price is zero

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.updateOracleForERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o2));
    }

    //----------------------------------
    // Un/Bonding Management

    function testListERC20AsBonding() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        // Set erc20 as being listed for bonding.
        // @todo Check event emission.
        reserve.listERC20AsBondable(address(erc20));
        assertEq(reserve.isERC20Bondable(address(erc20)), true);

        // Check that function is idempotent.
        reserve.listERC20AsBondable(address(erc20));
        assertEq(reserve.isERC20Bondable(address(erc20)), true);

        // Set erc20 as being delisted for bonding.
        reserve.delistERC20AsBondable(address(erc20));
        assertEq(reserve.isERC20Bondable(address(erc20)), false);

        // Check that function is idempotent.
        reserve.delistERC20AsBondable(address(erc20));
        assertEq(reserve.isERC20Bondable(address(erc20)), false);
    }

    function testListERC20AsBondable_NotAcceptedIf_ERC20NotRegistered()
        public
    {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC20NotRegistered);
        reserve.listERC20AsBondable(address(erc20));
    }

    function testListERC721IdAsBondable() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        // Set erc721Id as being listed as bondable.
        // @todo Check event emission.
        reserve.listERC721IdAsBondable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdBondable(address(erc721), DEFAULT_ERC721_ID), true);

        // Check that function is idempotent.
        reserve.listERC721IdAsBondable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdBondable(address(erc721), DEFAULT_ERC721_ID), true);

        // Set erc721Id as being delisted as bondable.
        reserve.delistERC721IdAsBondable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdBondable(address(erc721), DEFAULT_ERC721_ID), false);

        // Check that function is idempotent.
        reserve.delistERC721IdAsBondable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdBondable(address(erc721), DEFAULT_ERC721_ID), false);
    }

    function testListERC721IdAsBondable_NotAcceptedIf_ERC721IdNotRegistered()
        public
    {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC721IdNotRegistered);
        reserve.listERC721IdAsBondable(address(erc721), DEFAULT_ERC721_ID);
    }

    function testListERC20AsRedeemable() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC20(address(erc20), address(o), IReserve.AssetType.Default, IReserve.RiskLevel.Low);

        // Set erc20 as being listed as redeemable.
        // @todo Check event emission.
        reserve.listERC20AsRedeemable(address(erc20));
        assertEq(reserve.isERC20Redeemable(address(erc20)), true);

        // Check that function is idempotent.
        reserve.listERC20AsRedeemable(address(erc20));
        assertEq(reserve.isERC20Redeemable(address(erc20)), true);

        // Set erc20 as being delisted for redeemable.
        reserve.delistERC20AsRedeemable(address(erc20));
        assertEq(reserve.isERC20Redeemable(address(erc20)), false);

        // Check that function is idempotent.
        reserve.delistERC20AsRedeemable(address(erc20));
        assertEq(reserve.isERC20Redeemable(address(erc20)), false);
    }

    function testListERC20AsRedeemable_NotAcceptedIf_ERC20NotRegistered()
        public
    {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC20NotRegistered);
        reserve.listERC20AsRedeemable(address(erc20));
    }

    function testDelistERC20AsRedeemable_NotAcceptedIf_ERC20NotRegistered()
        public
    {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC20NotRegistered);
        reserve.delistERC20AsRedeemable(address(erc20));
    }

    function testListERC721IdAsRedeemable() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.registerERC721Id(address(erc721), DEFAULT_ERC721_ID, address(o));

        // Set erc721Id as being listed as redeemable.
        // @todo Check event emission.
        reserve.listERC721IdAsRedeemable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdRedeemable(address(erc721), DEFAULT_ERC721_ID), true);

        // Check that function is idempotent.
        reserve.listERC721IdAsRedeemable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdRedeemable(address(erc721), DEFAULT_ERC721_ID), true);

        // Set erc721Id as being delisted as redeemable.
        reserve.delistERC721IdAsRedeemable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdRedeemable(address(erc721), DEFAULT_ERC721_ID), false);

        // Check that function is idempotent.
        reserve.delistERC721IdAsRedeemable(address(erc721), DEFAULT_ERC721_ID);
        assertEq(reserve.isERC721IdRedeemable(address(erc721), DEFAULT_ERC721_ID), false);
    }

    function testListERC721IdAsRedeemable_NotAcceptedIf_ERC721IdNotRegistered()
        public
    {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC721IdNotRegistered);
        reserve.listERC721IdAsRedeemable(address(erc721), DEFAULT_ERC721_ID);
    }

    function testDelistERC721IdAsRedeemable_NotAcceptedIf_ERC721IdNotRegistered()
        public
    {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC721IdNotRegistered);
        reserve.delistERC721IdAsRedeemable(address(erc721), DEFAULT_ERC721_ID);
    }

    function testSetERC20BondingLimit(uint limit) public {
        // Note that erc20 does not need to be supported.
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));

        // @todo Check event emission.
        reserve.setERC20BondingLimit(address(erc20), limit);
        assertEq(reserve.bondingLimitPerERC20(address(erc20)), limit);

        // Check that function is idempotent.
        reserve.setERC20BondingLimit(address(erc20), limit);
        assertEq(reserve.bondingLimitPerERC20(address(erc20)), limit);
    }

    function testSetERC20RedeemLimit(uint limit) public {
        // Note that erc20 does not need to be supported.
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));

        // @todo Check event emission.
        reserve.setERC20RedeemLimit(address(erc20), limit);
        assertEq(reserve.redeemLimitPerERC20(address(erc20)), limit);

        // Check that function is idempotent.
        reserve.setERC20RedeemLimit(address(erc20), limit);
        assertEq(reserve.redeemLimitPerERC20(address(erc20)), limit);
    }

    //----------------------------------
    // Discount Management

    function testSetBondingDiscountForERC20(uint discount) public {
        // Note that erc20 does not need to be supported.
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));

        // @todo Check event emission.
        reserve.setBondingDiscountForERC20(address(erc20), discount);
        assertEq(reserve.bondingDiscountPerERC20(address(erc20)), discount);

        // Check that function is idempotent.
        reserve.setBondingDiscountForERC20(address(erc20), discount);
        assertEq(reserve.bondingDiscountPerERC20(address(erc20)), discount);
    }

    function testSetBondingDiscountForERC721Id(uint discount) public {
        // Note that erc721Id does not need to be supported.
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        // @todo Check event emission.
        reserve.setBondingDiscountForERC721Id(address(erc721), DEFAULT_ERC721_ID, discount);
        assertEq(reserve.bondingDiscountPerERC721Id(address(erc721), DEFAULT_ERC721_ID), discount);

        // Check that function is idempotent.
        reserve.setBondingDiscountForERC721Id(address(erc721), DEFAULT_ERC721_ID, discount);
        assertEq(reserve.bondingDiscountPerERC721Id(address(erc721), DEFAULT_ERC721_ID), discount);
    }

    //----------------------------------
    // Vesting Management

    function testSetVestingVault() public {
        VestingVaultMock vv = new VestingVaultMock(address(token));

        address oldVv = reserve.vestingVault();

        // @todo Check event emission.
        reserve.setVestingVault(address(vv));
        assertEq(reserve.vestingVault(), address(vv));

        // Check allowance.
        assertEq(token.allowance(address(reserve), address(vv)), type(uint).max);
        assertEq(token.allowance(address(reserve), address(oldVv)), 0);
    }

    function testSetVestingVault_NotAcceptedIf_WrongTokenSupported() public {
        VestingVaultMock vv = new VestingVaultMock(address(0));

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.setVestingVault(address(vv));
    }

    function testSetBondingVestingForERC20(uint vestingDuration) public {
        // Note that erc20 does not need to be supported.
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));

        // @todo Check event emission.
        reserve.setBondingVestingForERC20(address(erc20), vestingDuration);
        assertEq(
            reserve.bondingVestingDurationPerERC20(address(erc20)),
            vestingDuration
        );
    }

    function testSetBondingVestingForERC721Id(uint vestingDuration) public {
        // Note that erc721Id does not need to be supported.
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), DEFAULT_ERC721_ID);

        // @todo Check event emission.
        reserve.setBondingVestingForERC721Id(address(erc721), DEFAULT_ERC721_ID, vestingDuration);
        assertEq(
            reserve.bondingVestingDurationPerERC721Id(address(erc721), DEFAULT_ERC721_ID),
            vestingDuration
        );
    }

    //---------------------------------
    // Reserve Management

    function testSetMinBacking(uint minBacking) public {
        vm.assume(minBacking != 0);

        // @todo Check event emission.
        reserve.setMinBacking(minBacking);
        assertEq(reserve.minBacking(), minBacking);
    }

    function testSetMinBacking_NotAcceptedIf_IsZero() public {
        vm.expectRevert(bytes("")); // Empty require statement
        reserve.setMinBacking(0);
    }

    function testWithdrawERC20_FailsIf_InvalidAmount() public {
        vm.expectRevert(Errors.InvalidAmount);
        reserve.withdrawERC20(address(1), address(1), 0);
    }

    function testWithdrawERC20_FailsIf_InvalidRecipient() public {
        vm.expectRevert(Errors.InvalidRecipient);
        reserve.withdrawERC20(address(1), address(0), 1);

        vm.expectRevert(Errors.InvalidRecipient);
        reserve.withdrawERC20(address(1), address(reserve), 1);
    }

    function testWithdrawERC20_FailsIf_CodeIsZero() public {
        vm.expectRevert(bytes("")); // Empty require statement
        reserve.withdrawERC20(address(0), address(1), 1);
    }

    function testWithdrawERC20(address recipient, uint amount) public {
        vm.assume(recipient != address(0) && recipient != address(reserve));
        vm.assume(amount != 0);

        ERC20Mock erc20 = new ERC20Mock("TOKEN", "TKN", uint8(18));
        erc20.mint(address(reserve), amount);

        reserve.withdrawERC20(address(erc20), recipient, amount);
        assertEq(erc20.balanceOf(address(reserve)), 0);
        assertEq(erc20.balanceOf(address(recipient)), amount);
    }

    function testWithdrawERC721Id_FailsIf_InvalidRecipient() public {
        vm.expectRevert(Errors.InvalidRecipient);
        reserve.withdrawERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID, address(0));

        vm.expectRevert(Errors.InvalidRecipient);
        reserve.withdrawERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID, address(reserve));
    }

    function testWithdrawERC721Id(bool toEOA) public {
        address recipient;

        if (toEOA) {
            // Withdraw to EOA.
            recipient = address(1);

            // Send DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID to reserve.
            nft.safeTransferFrom(address(this), address(reserve), 1);

            reserve.withdrawERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID, recipient);
            assertEq(nft.ownerOf(1), recipient);
        } else {
            // Withdraw to contract that implements onERC721Receiver.
            recipient = address(this);

            // Send DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID to reserve.
            nft.safeTransferFrom(address(this), address(reserve), 1);

            reserve.withdrawERC721Id(DEFAULT_ERC721_ADDRESS, DEFAULT_ERC721_ID, recipient);
            assertEq(nft.ownerOf(1), recipient);
        }
    }

    // Note that the onlyOwner functions `incurDebt` and `payDebt` are tested
    // in the `FractionalReceiptBanking` test contract.

}
