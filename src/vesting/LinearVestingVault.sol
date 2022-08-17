// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {IERC20} from "../interfaces/_external/IERC20.sol";

import {VestingVault} from "./VestingVault.sol";

/**
 * @title Linear Vesting Vault
 *
 * @dev ...
 *
 * @author byterocket
 */
contract LinearVestingVault is VestingVault {

    constructor(address token_) VestingVault(token_) {
        // NO-OP
    }

    function depositFor(address recipient, uint amount, uint vestingDuration)
        external
        override(VestingVault)
    {
        // Fetch tokens.

    }

    function claim() external override(VestingVault) {

    }

    function getTotalVestedFor(address receiver)
        external
        override(VestingVault)
        view
        returns (uint)
    {
        return 0;
    }

    function getTotalClaimableFor(address receiver)
        external
        override(VestingVault)
        view
        returns (uint)
    {
        return 0;
    }

}
