// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Deployment Tests.
 */
contract GeoNFTDeployment is GeoNFTTest {

    function testInvariants() public {
        assertEq(geoNFT.owner(), address(this));
    }

    function testConstructor() public {
        assertEq(geoNFT.name(), name);
        assertEq(geoNFT.symbol(), symbol);
    }

}
