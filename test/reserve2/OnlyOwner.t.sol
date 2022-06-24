// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Test.t.sol";

contract Reserve2OnlyOwner is Reserve2Test {

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != reserve.owner());

        vm.startPrank(caller);

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
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

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
        bytes32 erc721IdHash = reserve.hashOfERC721Id(erc721Id);

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

    //----------------------------------
    // Discount Management

    //----------------------------------
    // Vesting Management

    //---------------------------------
    // Reserve Management
}
