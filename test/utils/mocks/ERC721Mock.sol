// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {ERC721} from "solmate/tokens/ERC721.sol";

contract ERC721Mock is ERC721 {

    constructor() ERC721("ERC721 Mock", "ERC721MOCK") {
        // NO-OP
    }

    function mint(address to, uint id) external {
        super._mint(to, id);
    }

    function burn(uint id) external {
        super._burn(id);
    }

    function tokenURI(uint id)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return "";
    }

}
