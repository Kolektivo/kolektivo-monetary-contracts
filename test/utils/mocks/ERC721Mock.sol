// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor() ERC721("ERC721 Mock", "ERC721MOCK") {
        // NO-OP
    }

    function mint(address to, uint256 id) external {
        super._mint(to, id);
    }

    function burn(uint256 id) external {
        super._burn(id);
    }

    function tokenURI(uint256 id) public view override(ERC721) returns (string memory) {
        return "";
    }
}
