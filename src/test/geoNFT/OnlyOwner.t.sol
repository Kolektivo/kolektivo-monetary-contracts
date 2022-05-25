// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

import "../../lib/GeoCoordinates.sol";

/**
 * @dev onlyOwner Function Tests.
 */
contract GeoNFTOnlyOwner is GeoNFTTest {

    function testOnlyOwnerFunctionsNotPubliclyCallable(address caller) public {
        if (caller == geoNFT.owner()) {
            return;
        }
        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByOwner);
        geoNFT.mint(address(1), 0, 0, "identifier");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        geoNFT.modify(0, 0, 0, "identifier");

        vm.expectRevert(Errors.OnlyCallableByOwner);
        geoNFT.burn(0);
    }

    function testMint(
        address to,
        int32 latitude,
        int32 longitude,
        string memory identifier
    ) public {
        // Expect revert if token recipient is zero address or address(geoNFT).
        if (to == address(0) || to == address(geoNFT)) {
            vm.expectRevert(Errors.InvalidRecipient);
            geoNFT.mint(to, latitude, longitude, identifier);
            return;
        }

        // Expect revert if latitude coordinate is invalid.
        if (!GeoCoordinates.isValidLatitudeCoordinate(latitude)) {
            vm.expectRevert(Errors.InvalidLatitude);
            geoNFT.mint(to, latitude, longitude, identifier);
            return;
        }

        // Expect revert if longitude coordinate is invalid.
        if (!GeoCoordinates.isValidLongitudeCoordinate(longitude)) {
            vm.expectRevert(Errors.InvalidLongitude);
            geoNFT.mint(to, latitude, longitude, identifier);
            return;
        }

        // Expect revert if identifier is invalid.
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

    function testModify(
        int32 latitude,
        int32 longitude,
        string memory identifier
    ) public {
        // Note that GeoNFT does not use safeMint, i.e. ERC721TokenReceiver is
        // not checked for contracts.
        _mintTokenTo(address(this));

        // Expect revert if latitude coordinate is invalid.
        if (!GeoCoordinates.isValidLatitudeCoordinate(latitude)) {
            vm.expectRevert(Errors.InvalidLatitude);
            geoNFT.modify(FIRST_TOKEN_ID, latitude, longitude, identifier);
            return;
        }

        // Expect revert if longitude coordinate is invalid.
        if (!GeoCoordinates.isValidLongitudeCoordinate(longitude)) {
            vm.expectRevert(Errors.InvalidLongitude);
            geoNFT.modify(FIRST_TOKEN_ID, latitude, longitude, identifier);
            return;
        }

        // Expect revert if identifier is invalid.
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

    function testBurn() public {
        _mintTokenTo(address(this));

        geoNFT.burn(FIRST_TOKEN_ID);

        // Check that token is not minted anymore.
        vm.expectRevert("NOT_MINTED"); // Thrown by ERC721 base contract dependency.
        geoNFT.ownerOf(FIRST_TOKEN_ID);

        // Check that old owner's balance decreased.
        assertEq(geoNFT.balanceOf(address(this)), 0);
    }

    function _mintTokenTo(address to) private {
        geoNFT.mint(to, 0, 0, "identifier");
    }

}
