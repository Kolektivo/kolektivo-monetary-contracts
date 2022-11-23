// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./Test.t.sol";

contract ReserveDeployment is ReserveTest {

    function testInvariants() public {
        // Check that owner is deployer.
        assertEq(reserve.owner(), address(this));

        // Check initial reserve status.
        uint reserveValuation;
        uint supplyValuation;
        uint backing;
        (reserveValuation, supplyValuation, backing) = reserve.reserveStatus();
        assertEq(reserveValuation, 0);
        assertEq(supplyValuation, 0);
        assertEq(backing, BPS);

        // Check vesting vault's token approval.
        assertEq(
            token.allowance(address(reserve), address(vestingVault)),
            type(uint).max
        );
    }

    function testConstructor() public {
        // Constructor arguments.
        assertEq(reserve.token(), address(token));
        assertEq(reserve.tokenOracle(), address(tokenOracle));
        assertEq(reserve.vestingVault(), address(vestingVault));
        assertEq(reserve.minBacking(), DEFAULT_MIN_BACKING);
    }

    function testConstructor_DoesNotAccept_TokenWithNoCode() public {
        vm.expectRevert(bytes("")); // Empty require statement.
        new Reserve(
            address(1), // Does not have any code
            address(tokenOracle),
            address(vestingVault),
            DEFAULT_MIN_BACKING
        );
    }

    /*
    @todo function testConstructor_DoesNotAccept_InvalidOracle() public {
        // Invalid oracle.
        tokenOracle.setDataAndValid(1e18, false);

        vm.expectRevert(bytes("")); // Empty require statement.
        new Reserve(
            address(token),
            address(tokenOracle),
            address(vestingVault),
            DEFAULT_MIN_BACKING
        );

        // Oracle's price is zero.
        tokenOracle.setDataAndValid(0, true);

        vm.expectRevert(bytes("")); // Empty require statement.
        new Reserve(
            address(token),
            address(tokenOracle),
            address(vestingVault),
            DEFAULT_MIN_BACKING
        );
    }
    */

    /*
    @todo function testConstructor_DoesNotAccept_VestingVaultWithWrongToken() public {
        VestingVaultMock vv = new VestingVaultMock(address(0));

        vm.expectRevert(bytes("")); // Empty require statement.
        new Reserve(
            address(token),
            address(tokenOracle),
            address(vv),
            DEFAULT_MIN_BACKING
        );
    }
    */

}
