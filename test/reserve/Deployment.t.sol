// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Deployment Tests.
 */
contract ReserveDeployment is ReserveTest {

    function testInvariants() public {
        // Ownable invariants.
        assertEq(reserve.owner(), address(this));

        // Reserve status.
        uint reserve_;
        uint supply;
        uint backingInBPS;
        (reserve_, supply, backingInBPS) = reserve.reserveStatus();

        assertEq(reserve_, 0);
        assertEq(supply, 0);
        assertEq(backingInBPS, BPS);
    }

    function testConstructor() public {
        // Constructor arguments.
        assertEq(reserve.kol(), address(kol));
        assertEq(reserve.ktt(), address(ktt));
        assertEq(reserve.minBackingInBPS(), DEFAULT_MIN_BACKING);
    }

}
