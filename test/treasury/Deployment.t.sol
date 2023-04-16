// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Deployment Tests.
 */
contract TreasuryDeployment is TreasuryTest {
    function testInvariants() public {
        assertEq(treasury.name(), "Kolektivo Treasury Token");
        assertEq(treasury.symbol(), "KTT");
        assertEq(treasury.decimals(), uint8(18));

        assertEq(treasury.owner(), address(this));
    }
}
