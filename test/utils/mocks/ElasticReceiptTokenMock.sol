// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import "src/ElasticReceiptToken.sol";

contract ElasticReceiptTokenMock is ElasticReceiptToken {
    // The token's underlier.
    // Is of type ERC20.
    address public underlier;

    constructor(address underlier_, string memory name_, string memory symbol_, uint8 decimals_)
        ElasticReceiptToken(name_, symbol_, decimals_)
    {
        underlier = underlier_;
    }

    function _supplyTarget() internal view override(ElasticReceiptToken) returns (uint256) {
        return ERC20(underlier).balanceOf(address(this));
    }

    function mint(uint256 tokens) external {
        super._mint(msg.sender, tokens);
        ERC20(underlier).transferFrom(msg.sender, address(this), tokens);
    }

    function burn(uint256 erts) external {
        erts = super._burn(msg.sender, erts);
        ERC20(underlier).transfer(msg.sender, erts);
    }
}
