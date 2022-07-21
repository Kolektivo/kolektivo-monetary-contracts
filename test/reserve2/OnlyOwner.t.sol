// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Test.t.sol";

contract Reserve2OnlyOwner is Reserve2Test {

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != reserve.owner());

        vm.startPrank(caller);

        IReserve2.ERC721Id memory erc721Id = IReserve2.ERC721Id(address(1), 1);

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
        reserve.bondERC721Id(erc721Id);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC721IdFrom(erc721Id, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC721IdTo(erc721Id, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.bondERC721IdFromTo(erc721Id, address(1), address(1));

        //----------------------------------
        // Unbond Functions

        //--------------
        // Unbond ERC20 Functions

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20(address(0), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20From(address(0), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20To(address(0), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20FromTo(address(0), address(1), address(1), 0);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20All(address(0));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20AllFrom(address(0), address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20AllTo(address(0), address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC20AllFromTo(address(0), address(1), address(1));

        //--------------
        // Unbond ERC721Id Functions

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC721Id(erc721Id);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC721IdFrom(erc721Id, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC721IdTo(erc721Id, address(1));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unbondERC721IdFromTo(erc721Id, address(1), address(1));

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
        reserve.supportERC20(address(token), address(tokenOracle));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.supportERC721Id(
            DEFAULT_ERC721ID,
            address(defaultERC721IdOracle)
        );

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unsupportERC20(address(token));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.unsupportERC721Id(DEFAULT_ERC721ID);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.updateOracleForERC20(address(token), address(tokenOracle));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.updateOracleForERC721Id(
            DEFAULT_ERC721ID,
            address(defaultERC721IdOracle)
        );

        //----------------------------------
        // Un/Bonding Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.supportERC20ForBonding(address(token), true);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.supportERC721IdForBonding(DEFAULT_ERC721ID, true);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.supportERC20ForUnbonding(address(token), true);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.supportERC721IdForUnbonding(DEFAULT_ERC721ID, true);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setERC20BondingLimit(address(token), 1e18);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setERC20UnbondingLimit(address(token), 1e18);

        //----------------------------------
        // Discount Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setDiscountForERC20(address(token), 1e18);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setDiscountForERC721Id(DEFAULT_ERC721ID, 1e18);

        //----------------------------------
        // Vesting Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setVestingVault(address(vestingVault));

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setVestingForERC20(address(token), 1 hours);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setVestingForERC721Id(DEFAULT_ERC721ID, 1 hours);

        //---------------------------------
        // Reserve Management

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.setMinBacking(1e18);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.withdrawERC20(address(1), address(1), 1);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        reserve.withdrawERC721Id(DEFAULT_ERC721ID, address(1));

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

    function testSupportERC20() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        // @todo Check event emission.
        reserve.supportERC20(address(erc20), address(o));
        assertEq(reserve.supportedERC20s(0), address(erc20));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o));

        // Check that function is idempotent.
        reserve.supportERC20(address(erc20), address(o));
        assertEq(reserve.supportedERC20s(0), address(erc20));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o));

        // Reverts due to IndexOutOfBounds.
        // This indicates that the erc20 was not added again, i.e. that the
        // function is idempotent.
        vm.expectRevert(bytes(""));
        reserve.supportedERC20s(1);
    }

    function testSupportERC20_NotAcceptedIf_TokenCodeIsZero() public {
        address erc20 = address(0); // erc20 has no code

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC20(erc20, address(0));
    }

    function testSupportERC20_NotAcceptedIf_AlreadySupported() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC20(address(erc20), address(o));

        // Reverts if erc20 is added again with a different oracle.
        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC20(address(erc20), address(o2));
    }

    function testSupportERC20_NotAcceptedIf_OracleInvalid() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, false); // Oracle is invalid

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC20(address(erc20), address(o));

        o.setDataAndValid(0, true); // Oracle's price is zero

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC20(address(erc20), address(o));
    }

    function testSupportERC721() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        // @todo Check event emission
        reserve.supportERC721Id(erc721Id, address(o));

        (address addedERC721, uint addedId) = reserve.supportedERC721Ids(0);
        assertEq(addedERC721, erc721Id.erc721);
        assertEq(addedId, erc721Id.id);
        assertEq(reserve.oraclePerERC721Id(erc721IdHash), address(o));

        // Check that function is idempotent.
        reserve.supportERC721Id(erc721Id, address(o));

        (addedERC721, addedId) = reserve.supportedERC721Ids(0);
        assertEq(addedERC721, erc721Id.erc721);
        assertEq(addedId, erc721Id.id);
        assertEq(reserve.oraclePerERC721Id(erc721IdHash), address(o));

        // Reverts due to IndexOutOfBounds.
        // This indicates that the erc721Id was not added again, i.e. that the
        // function is idempotent.
        vm.expectRevert(bytes(""));
        reserve.supportedERC721Ids(1);
    }

    function testSupportERC721_NotAcceptedIf_TokenCodeIsZero() public {
        IReserve2.ERC721Id memory erc721Id = IReserve2.ERC721Id(
            address(0), // ERC721 code is empty
            1
        );

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC721Id(erc721Id, address(o));
    }

    function testSupportERC721_NotAcceptedIf_AlreadySupported() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC721Id(erc721Id, address(o));

        // Reverts is ERC721Id is added again with different oracle.
        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC721Id(erc721Id, address(o2));
    }

    function testSupportERC721_NotAcceptedIf_OracleInvalid() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, false); // Oracle is invalid

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC721Id(erc721Id, address(o));

        o.setDataAndValid(0, true); // Oracle's price is zero

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportERC721Id(erc721Id, address(o));
    }

    function testUnsupportERC20() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC20(address(erc20), address(o));

        // @todo Check event emission.
        reserve.unsupportERC20(address(erc20));

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportedERC20s(0);
        assertEq(reserve.oraclePerERC20(address(erc20)), address(0));

        // Check that function is idempotent.
        reserve.unsupportERC20(address(erc20));

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportedERC20s(0);
        assertEq(reserve.oraclePerERC20(address(erc20)), address(0));
    }

    function testUnsupportERC721Id() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC721Id(erc721Id, address(o));

        // @todo Check event emission
        reserve.unsupportERC721Id(erc721Id);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportedERC721Ids(0);
        assertEq(reserve.oraclePerERC721Id(erc721IdHash), address(0));

        // Check that function is idempotent.
        reserve.unsupportERC721Id(erc721Id);

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.supportedERC721Ids(0);
        assertEq(reserve.oraclePerERC721Id(erc721IdHash), address(0));
    }

    function testUpdateOracleForERC20() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC20(address(erc20), address(o));

        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        // @todo Check event emission.
        reserve.updateOracleForERC20(address(erc20), address(o2));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o2));

        // Check that function is idempotent.
        reserve.updateOracleForERC20(address(erc20), address(o2));
        assertEq(reserve.oraclePerERC20(address(erc20)), address(o2));
    }

    function testUpdateOracleForERC20_NotAcceptedIf_ERC20NotSupported()
        public
    {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC20NotSupported);
        reserve.updateOracleForERC20(address(erc20), address(o));
    }

    function testUpdateOracleForERC20_NotAcceptedIf_OracleInvalid() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC20(address(erc20), address(o));

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
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC721Id(erc721Id, address(o));

        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, true);

        // @todo Check event emission.
        reserve.updateOracleForERC721Id(erc721Id, address(o2));
        assertEq(reserve.oraclePerERC721Id(erc721IdHash), address(o2));

        // Check that function is idempotent.
        reserve.updateOracleForERC721Id(erc721Id, address(o2));
        assertEq(reserve.oraclePerERC721Id(erc721IdHash), address(o2));
    }

    function testUpdateOracleForERC721Id_NotAcceptedIf_ERC721IdNotSupported()
        public
    {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC721IdNotSupported);
        reserve.updateOracleForERC721Id(erc721Id, address(o));
    }

    function testUpdateOracleForERC721Id_NotAcceptedIf_OracleInvalid() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC721Id(erc721Id, address(o));

        OracleMock o2 = new OracleMock();
        o2.setDataAndValid(1e18, false); // Oracle is invalid

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.updateOracleForERC721Id(erc721Id, address(o2));

        o2.setDataAndValid(0, true); // Oracle's price is zero

        vm.expectRevert(bytes("")); // Empty require statement
        reserve.updateOracleForERC721Id(erc721Id, address(o2));
    }

    //----------------------------------
    // Un/Bonding Management

    function testSupportERC20ForBonding() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC20(address(erc20), address(o));

        // Set erc20 as being supported for bonding.
        // @todo Check event emission.
        reserve.supportERC20ForBonding(address(erc20), true);
        assertEq(reserve.isERC20Bondable(address(erc20)), true);

        // Check that function is idempotent.
        reserve.supportERC20ForBonding(address(erc20), true);
        assertEq(reserve.isERC20Bondable(address(erc20)), true);

        // Set erc20 as being unsupported for bonding.
        reserve.supportERC20ForBonding(address(erc20), false);
        assertEq(reserve.isERC20Bondable(address(erc20)), false);

        // Check that function is idempotent.
        reserve.supportERC20ForBonding(address(erc20), false);
        assertEq(reserve.isERC20Bondable(address(erc20)), false);
    }

    function testSupportERC20ForBonding_NotAcceptedIf_ERC20NotSupported()
        public
    {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC20NotSupported);
        reserve.supportERC20ForBonding(address(erc20), true);
    }

    function testSupportERC721IdForBonding() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC721Id(erc721Id, address(o));

        // Set erc721Id as being supported for bonding.
        // @todo Check event emission.
        reserve.supportERC721IdForBonding(erc721Id, true);
        assertEq(reserve.isERC721IdBondable(erc721IdHash), true);

        // Check that function is idempotent.
        reserve.supportERC721IdForBonding(erc721Id, true);
        assertEq(reserve.isERC721IdBondable(erc721IdHash), true);

        // Set erc721Id as being unsupported for bonding.
        reserve.supportERC721IdForBonding(erc721Id, false);
        assertEq(reserve.isERC721IdBondable(erc721IdHash), false);

        // Check that function is idempotent.
        reserve.supportERC721IdForBonding(erc721Id, false);
        assertEq(reserve.isERC721IdBondable(erc721IdHash), false);
    }

    function testSupportERC721IdForBonding_NotAcceptedIf_ERC721IdNotSupported()
        public
    {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC721IdNotSupported);
        reserve.supportERC721IdForBonding(erc721Id, true);
    }

    function testSupportERC20ForUnbonding() public {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC20(address(erc20), address(o));

        // Set erc20 as being supported for unbonding.
        // @todo Check event emission.
        reserve.supportERC20ForUnbonding(address(erc20), true);
        assertEq(reserve.isERC20Unbondable(address(erc20)), true);

        // Check that function is idempotent.
        reserve.supportERC20ForUnbonding(address(erc20), true);
        assertEq(reserve.isERC20Unbondable(address(erc20)), true);

        // Set erc20 as being unsupported for unbonding.
        reserve.supportERC20ForUnbonding(address(erc20), false);
        assertEq(reserve.isERC20Unbondable(address(erc20)), false);

        // Check that function is idempotent.
        reserve.supportERC20ForUnbonding(address(erc20), false);
        assertEq(reserve.isERC20Unbondable(address(erc20)), false);
    }

    function testSupportERC20ForUnbonding_NotAcceptedIf_ERC20NotSupported()
        public
    {
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC20NotSupported);
        reserve.supportERC20ForUnbonding(address(erc20), true);

        vm.expectRevert(Errors.ERC20NotSupported);
        reserve.supportERC20ForUnbonding(address(erc20), false);
    }

    function testSupportERC721IdForUnbonding() public {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        reserve.supportERC721Id(erc721Id, address(o));

        // Set erc721Id as being supported for unbonding.
        // @todo Check event emission.
        reserve.supportERC721IdForUnbonding(erc721Id, true);
        assertEq(reserve.isERC721IdUnbondable(erc721IdHash), true);

        // Check that function is idempotent.
        reserve.supportERC721IdForUnbonding(erc721Id, true);
        assertEq(reserve.isERC721IdUnbondable(erc721IdHash), true);

        // Set erc721Id as being unsupported for unbonding.
        reserve.supportERC721IdForUnbonding(erc721Id, false);
        assertEq(reserve.isERC721IdUnbondable(erc721IdHash), false);

        // Check that function is idempotent.
        reserve.supportERC721IdForUnbonding(erc721Id, false);
        assertEq(reserve.isERC721IdUnbondable(erc721IdHash), false);
    }

    function testSupportERC721IdForUnbonding_NotAcceptedIf_ERC721IdNotSupported()
        public
    {
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);

        OracleMock o = new OracleMock();
        o.setDataAndValid(1e18, true);

        vm.expectRevert(Errors.ERC721IdNotSupported);
        reserve.supportERC721IdForUnbonding(erc721Id, true);
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

    function testSetERC20UnbondingLimit(uint limit) public {
        // Note that erc20 does not need to be supported.
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));

        // @todo Check event emission.
        reserve.setERC20UnbondingLimit(address(erc20), limit);
        assertEq(reserve.unbondingLimitPerERC20(address(erc20)), limit);

        // Check that function is idempotent.
        reserve.setERC20UnbondingLimit(address(erc20), limit);
        assertEq(reserve.unbondingLimitPerERC20(address(erc20)), limit);
    }

    //----------------------------------
    // Discount Management

    function testSetDiscountForERC20(uint discount) public {
        // Note that erc20 does not need to be supported.
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));

        // @todo Check event emission.
        reserve.setDiscountForERC20(address(erc20), discount);
        assertEq(reserve.discountPerERC20(address(erc20)), discount);

        // Check that function is idempotent.
        reserve.setDiscountForERC20(address(erc20), discount);
        assertEq(reserve.discountPerERC20(address(erc20)), discount);
    }

    function testSetDiscountForERC721Id(uint discount) public {
        // Note that erc721Id does not need to be supported.
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

        // @todo Check event emission.
        reserve.setDiscountForERC721Id(erc721Id, discount);
        assertEq(reserve.discountPerERC721Id(erc721IdHash), discount);

        // Check that function is idempotent.
        reserve.setDiscountForERC721Id(erc721Id, discount);
        assertEq(reserve.discountPerERC721Id(erc721IdHash), discount);
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

    function testSetVestingForERC20(uint vestingDuration) public {
        // Note that erc20 does not need to be supported.
        ERC20Mock erc20 = new ERC20Mock("MOCK", "Mock Token", uint8(18));

        // @todo Check event emission.
        reserve.setVestingForERC20(address(erc20), vestingDuration);
        assertEq(
            reserve.vestingDurationPerERC20(address(erc20)),
            vestingDuration
        );
    }

    function testSetVestingForERC721Id(uint vestingDuration) public {
        // Note that erc721Id does not need to be supported.
        ERC721Mock erc721 = new ERC721Mock();
        erc721.mint(address(this), 1);
        IReserve2.ERC721Id memory erc721Id
            = IReserve2.ERC721Id(address(erc721), 1);
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

        // @todo Check event emission.
        reserve.setVestingForERC721Id(erc721Id, vestingDuration);
        assertEq(
            reserve.vestingDurationPerERC721Id(erc721IdHash),
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
        reserve.withdrawERC721Id(DEFAULT_ERC721ID, address(0));

        vm.expectRevert(Errors.InvalidRecipient);
        reserve.withdrawERC721Id(DEFAULT_ERC721ID, address(reserve));
    }

    function testWithdrawERC721Id(address recipient) public {
        vm.assume(recipient != address(0) && recipient != address(reserve));

        // Send DEFAULT_ERC721ID to reserve.
        nft.safeTransferFrom(address(this), address(reserve), 1);

        reserve.withdrawERC721Id(DEFAULT_ERC721ID, recipient);
        assertEq(nft.ownerOf(1), recipient);
    }

    // Note that the onlyOwner functions `incurDebt` and `payDebt` are tested
    // in the `FractionalReceiptBanking` test contract.

}
