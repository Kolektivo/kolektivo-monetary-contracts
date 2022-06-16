// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/GeoNFT.sol";
import "src/lib/GeoCoordinates.sol";

/**
 * Errors library for GeoNFT's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    bytes internal constant OnlyCallableByOwner =
        abi.encodeWithSignature("OnlyCallableByOwner()");

    bytes internal constant InvalidTokenId =
        abi.encodeWithSignature("GeoNFT__InvalidTokenId()");

    bytes internal constant InvalidRecipient =
        abi.encodeWithSignature("GeoNFT__InvalidRecipient()");

    bytes internal constant InvalidLatitude =
        abi.encodeWithSignature("GeoNFT__InvalidLatitude()");

    bytes internal constant InvalidLongitude =
        abi.encodeWithSignature("GeoNFT__InvalidLongitude()");

    bytes internal constant InvalidIdentifier =
        abi.encodeWithSignature("GeoNFT__InvalidIdentifier()");
}

/**
 * @dev Root contract for GeoNFT Test Contracts.
 *
 *      Provides the setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
contract GeoNFTTest is Test {
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

    //--------------------------------------------------------------------------
    // Deployment Tests

    function testDeploymentInvariants() public {
        assertEq(geoNFT.owner(), address(this));
    }

    function testDeploymentConstructor() public {
        assertEq(geoNFT.name(), name);
        assertEq(geoNFT.symbol(), symbol);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Tests

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        vm.assume(caller != geoNFT.owner());
        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        geoNFT.mint(address(1), 0, 0, "identifier");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        geoNFT.modify(0, 0, 0, "identifier");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        geoNFT.burn(0);
    }

    //--------------------------------------------------------------------------
    // Mint Tests

    function testMint(
        address to,
        int32 latitude,
        int32 longitude,
        string memory identifier
    ) public {
        // Expect revert if token recipient is zero address or address(geoNFT).
        // Modifier: validRecipient.
        if (to == address(0) || to == address(geoNFT)) {
            vm.expectRevert(Errors.InvalidRecipient);
            geoNFT.mint(to, latitude, longitude, identifier);
            return;
        }

        // Expect revert if latitude coordinate is invalid.
        // Modifier: validLatitude.
        if (!GeoCoordinates.isValidLatitudeCoordinate(latitude)) {
            vm.expectRevert(Errors.InvalidLatitude);
            geoNFT.mint(to, latitude, longitude, identifier);
            return;
        }

        // Expect revert if longitude coordinate is invalid.
        // Modifier: validLongitude.
        if (!GeoCoordinates.isValidLongitudeCoordinate(longitude)) {
            vm.expectRevert(Errors.InvalidLongitude);
            geoNFT.mint(to, latitude, longitude, identifier);
            return;
        }

        // Expect revert if identifier is invalid.
        // Modifier: validIdentifier.
        if (bytes(identifier).length == 0) {
            vm.expectRevert(Errors.InvalidIdentifier);
            geoNFT.mint(to, latitude, longitude, identifier);
            return;
        }

        // Otherwise expect token to be minted.
        geoNFT.mint(to, latitude, longitude, identifier);

        // Check token owner.
        assertEq(geoNFT.ownerOf(FIRST_TOKEN_ID), to);
        assertEq(geoNFT.balanceOf(to), 1);

        // Check token data.
        uint gotlastModified;
        int32 gotLatitude;
        int32 gotLongitude;
        string memory gotIdentifier;
        (gotlastModified, gotLatitude, gotLongitude, gotIdentifier)
            = geoNFT.tokenData(FIRST_TOKEN_ID);

        assertEq(gotlastModified, block.timestamp);
        assertEq(gotLatitude, latitude);
        assertEq(gotLongitude, longitude);
        assertEq(gotIdentifier, identifier);

        // Mint another token to verify token id is incremented correctly.
        // Note that it's fine to have two tokes with the exact same data.
        geoNFT.mint(to, latitude, longitude, identifier);

        // Only check that token id is incremented correctly.
        assertEq(geoNFT.ownerOf(FIRST_TOKEN_ID + 1), to);
    }

    //--------------------------------------------------------------------------
    // Modify Tests

    function testModify(
        int32 latitude,
        int32 longitude,
        string memory identifier
    ) public {
        // Note that GeoNFT does not use safeMint, i.e. ERC721TokenReceiver is
        // not checked for contracts.
        _mintTokenTo(address(this));

        // Expect revert if latitude coordinate is invalid.
        // Modifier: validLatitude.
        if (!GeoCoordinates.isValidLatitudeCoordinate(latitude)) {
            vm.expectRevert(Errors.InvalidLatitude);
            geoNFT.modify(FIRST_TOKEN_ID, latitude, longitude, identifier);
            return;
        }

        // Expect revert if longitude coordinate is invalid.
        // Modifier: validLongitude.
        if (!GeoCoordinates.isValidLongitudeCoordinate(longitude)) {
            vm.expectRevert(Errors.InvalidLongitude);
            geoNFT.modify(FIRST_TOKEN_ID, latitude, longitude, identifier);
            return;
        }

        // Expect revert if identifier is invalid.
        // Modifier: validIdentifier.
        if (bytes(identifier).length == 0) {
            vm.expectRevert(Errors.InvalidIdentifier);
            geoNFT.modify(FIRST_TOKEN_ID, latitude, longitude, identifier);
            return;
        }

        // Otherwise expect token to be modified.
        vm.expectEmit(true, true, true, true);
        emit TokenModified(FIRST_TOKEN_ID);

        geoNFT.modify(FIRST_TOKEN_ID, latitude, longitude, identifier);

        // Check that token owner did not change.
        assertEq(geoNFT.ownerOf(FIRST_TOKEN_ID), address(this));

        // Check token data.
        uint gotlastModified;
        int32 gotLatitude;
        int32 gotLongitude;
        string memory gotIdentifier;
        (gotlastModified, gotLatitude, gotLongitude, gotIdentifier)
            = geoNFT.tokenData(FIRST_TOKEN_ID);

        assertEq(gotlastModified, block.timestamp);
        assertEq(gotLatitude, latitude);
        assertEq(gotLongitude, longitude);
        assertEq(gotIdentifier, identifier);
    }

    function testModifyInvalidTokenId(uint tokenId) public {
        // Don't go to crazy with minting.
        vm.assume(tokenId > 0 && tokenId < 10);

        // Mint tokenId - 1 NFTs.
        for (uint i; i < tokenId - 1; i++) {
            _mintTokenTo(address(1));
        }

        // Modifying non-existing tokenId should revert.
        // Modifer: validTokenId.
        vm.expectRevert(Errors.InvalidTokenId);
        geoNFT.modify(tokenId, 0, 0, "");
    }

    //--------------------------------------------------------------------------
    // Burn Tests

    function testBurn() public {
        _mintTokenTo(address(this));

        geoNFT.burn(FIRST_TOKEN_ID);

        // Check that token is not minted anymore.
        vm.expectRevert("NOT_MINTED"); // Thrown by ERC721 base contract dependency.
        geoNFT.ownerOf(FIRST_TOKEN_ID);

        // Check that old owner's balance decreased.
        assertEq(geoNFT.balanceOf(address(this)), 0);
    }

    function testBurnInvalidTokenId(uint tokenId) public {
        // Don't go to crazy with minting.
        vm.assume(tokenId > 0 && tokenId < 10);

        // Mint tokenId - 1 NFTs.
        for (uint i; i < tokenId - 1; i++) {
            _mintTokenTo(address(1));
        }

        // Burning non-existing tokenId should revert.
        // Modifier: validTokenId.
        vm.expectRevert(Errors.InvalidTokenId);
        geoNFT.burn(tokenId);
    }

    //--------------------------------------------------------------------------
    // Helper

    function _mintTokenTo(address to) private {
        geoNFT.mint(to, 0, 0, "identifier");
    }

}
