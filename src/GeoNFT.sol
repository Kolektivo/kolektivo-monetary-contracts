// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC721} from "solmate/tokens/ERC721.sol";

import {TSOwnable} from "solrocket/TSOwnable.sol";

import {GeoCoordinates} from "./lib/GeoCoordinates.sol";

/**
 * @notice GeoNFT
 *
 * @dev The GeoNFT contract is an ERC721 NFT implementation.
 *      Each token is associated with a TokenData struct encapsulating it's
 *      metadata and geographical coordinates using latitude and longitude
 *      coordinates.
 *
 *      The GeoNFT contract is owned by an address. Only the owner is eligible
 *      to mint and burn tokens. Furthermore, the owner is also eligible to
 *      modify already existing token's metadata.
 *
 * @author byterocket
 */
contract GeoNFT is ERC721, TSOwnable {

    //--------------------------------------------------------------------------
    // Types

    /// @dev TokenData encapsulates a token's metadata.
    struct TokenData {
        /// @dev The timestamp the token data was last modified.
        uint lastModified;
        /// @dev The token's latitude coordinate.
        int32 latitude;
        /// @dev The token's longitude coordinate.
        int32 longitude;
        /// @dev The token's string identifier.
        string identifier;
    }

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid token id.
    error GeoNFT__InvalidTokenId();

    /// @notice Invalid token recipient.
    error GeoNFT__InvalidRecipient();

    /// @notice Invalid latitude coordinate.
    error GeoNFT__InvalidLatitude();

    /// @notice Invalid longitude coordinate.
    error GeoNFT__InvalidLongitude();

    /// @notice Invalid identifier.
    error GeoNFT__InvalidIdentifier();

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when a token's data is modified.
    event TokenModified(uint indexed id);

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token id is valid.
    modifier validTokenId(uint id) {
        if (id > _tokenCounter) {
            revert GeoNFT__InvalidTokenId();
        }
        _;
    }

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0) || to == address(this)) {
            revert GeoNFT__InvalidRecipient();
        }
        _;
    }

    /// @dev Modifier to guarantee latitude coordinate is valid.
    modifier validLatitude(int32 latitude) {
        if (!GeoCoordinates.isValidLatitudeCoordinate(latitude)) {
            revert GeoNFT__InvalidLatitude();
        }
        _;
    }

    /// @dev Modifier to guarantee longitude coordinate is valid.
    modifier validLongitude(int32 longitude) {
        if (!GeoCoordinates.isValidLongitudeCoordinate(longitude)) {
            revert GeoNFT__InvalidLongitude();
        }
        _;
    }

    /// @dev Modifier to guarantee identifier is valid.
    modifier validIdentifier(string memory got) {
        if (bytes(got).length == 0) {
            revert GeoNFT__InvalidIdentifier();
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Storage

    /// @dev Mapping of token id to tokenData struct.
    mapping(uint => TokenData) private _tokenData;

    /// @dev The last token's id created.
    uint private _tokenCounter;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {
        // NO-OP
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @notice Returns the token's data.
    /// @dev Reverts if token id is invalid.
    /// @param id The token's id.
    /// @return uint The timestamp the token was last modified.
    /// @return int32 The token's latitude coordinate.
    /// @return int32 The token's longitude coordinate.
    /// @return string The token's string identifier.
    function tokenData(uint id)
        external
        validTokenId(id)
        view
        returns (uint, int32, int32, string memory)
    {
        TokenData memory data = _tokenData[id];

        return (
            data.lastModified,
            data.latitude,
            data.longitude,
            data.identifier
        );
    }

    // @todo tokenURI
    function tokenURI(uint id)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return "";
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    /// @notice Mints a new token with given coordinates and identifier
    ///         to some address.
    /// @dev Only callable by owner.
    /// @dev Reverts if an argument is invalid.
    /// @param to The address to mint to the token to.
    /// @param latitude The token's latitude coordinate.
    /// @param longitude The token's longitude coordinate.
    /// @param identifier The token's string identifier.
    function mint(
        address to,
        int32 latitude,
        int32 longitude,
        string memory identifier
    )
        external
        onlyOwner
        validRecipient(to)
        validLatitude(latitude)
        validLongitude(longitude)
        validIdentifier(identifier)
    {
        // Increase token counter and cache result in memory variable.
        uint id = ++_tokenCounter;

        // Encapsulate data in a TokenData struct.
        TokenData memory data = TokenData(
            block.timestamp,
            latitude,
            longitude,
            identifier
        );

        // Save associated data.
        _tokenData[id] = data;

        // Mint token.
        // Note that safeMint is not used, i.e. ERC721TokenReceiver is not
        // checked for contracts.
        super._mint(to, id);
    }

    /// @notice Modifies a token's data.
    /// @dev Only callable by owner.
    /// @dev Reverts if an argument is invalid.
    /// @param id The token's id.
    /// @param latitude The token's latitude coordinate.
    /// @param longitude The token's longitude coordinate.
    /// @param identifier The token's string identifier.
    function modify(
        uint id,
        int32 latitude,
        int32 longitude,
        string memory identifier
    )
        external
        onlyOwner
        validTokenId(id)
        validLatitude(latitude)
        validLongitude(longitude)
        validIdentifier(identifier)
    {
        // Encapsulate data in a TokenData struct.
        TokenData memory data = TokenData(
            block.timestamp,
            latitude,
            longitude,
            identifier
        );

        // Save associated data.
        _tokenData[id] = data;

        // Notify off-chain services.
        emit TokenModified(id);
    }

    /// @notice Burns a token.
    /// @dev Only callable by owner.
    /// @dev Reverts if token id is invalid.
    /// @param id The token's id.
    function burn(
        uint id
    ) external onlyOwner validTokenId(id) {
        // Delete associated data.
        delete _tokenData[id];

        // Burn token.
        super._burn(id);
    }

}
