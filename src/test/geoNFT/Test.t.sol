// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "../../GeoNFT.sol";

/**
 * Errors library for GeoNFT's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner
        = abi.encodeWithSignature("OnlyCallableByOwner()");

    bytes internal constant InvalidTokenId
        = abi.encodeWithSignature("InvalidTokenId()");

    bytes internal constant InvalidRecipient
        = abi.encodeWithSignature("InvalidRecipient()");

    bytes internal constant InvalidLatitude
        = abi.encodeWithSignature("InvalidLatitude()");

    bytes internal constant InvalidLongitude
        = abi.encodeWithSignature("InvalidLongitude()");

    bytes internal constant InvalidIdentifier
        = abi.encodeWithSignature("InvalidIdentifier()");
}

/**
 * @dev Root contract for GeoNFT Test Contracts.
 *
 *      Provides the setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
abstract contract GeoNFTTest is Test {
    // SuT.
    GeoNFT geoNFT;

    // Event copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event TokenModified(uint indexed id);

    // Contructor arguments.
    string internal constant name = "GeoNFT";
    string internal constant symbol = "GNFT";

    // Other constants.
    uint internal constant FIRST_TOKEN_ID = 1;

    //--------------------------------------------------------------------------
    // Set Up Functions

    function setUp() public {
        geoNFT = new GeoNFT(name, symbol);
    }

}
