// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {IERC20} from "../interfaces/_external/IERC20.sol";

import {TSOwnable} from "solrocket/TSOwnable.sol";

import {VestingVault} from "./VestingVault.sol";

/**
 * @title Linear Vesting Vault
 *
 * @dev ...
 *
 * @author byterocket
 */
contract LinearVestingVault is VestingVault {

    constructor(address token_) {
        require(token_ != address(0));
        require(token_.code.length != 0);

        token = token_;
    }

    function depositFor(address recipient, uint amount) external {
        // Fetch tokens.

    }

}
