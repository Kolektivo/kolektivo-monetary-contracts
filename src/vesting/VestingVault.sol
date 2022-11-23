// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {IERC20} from "../interfaces/_external/IERC20.sol";

import {IVestingVault} from "../interfaces/IVestingVault.sol";

import {TSOwnable} from "solrocket/TSOwnable.sol";

/**
 * @title Vesting Vault
 *
 * @dev ...
 *
 * @author byterocket
 */
abstract contract VestingVault is TSOwnable, IVestingVault {

    address public immutable token;

    //mapping(address => )

    constructor(address token_) {
        require(token_ != address(0));
        require(token_.code.length != 0);

        token = token_;
    }

    function depositFor(address recipient, uint amount, uint vestingDuration)
        external
        virtual;

    function claim() external virtual;

    function vestedFor(address recipient) external virtual view returns (uint);

    function unvestedFor(address recipient)
        external
        virtual
        view
        returns (uint);

}
