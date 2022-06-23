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

}
