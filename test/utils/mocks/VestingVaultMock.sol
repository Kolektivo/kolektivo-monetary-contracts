// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {IVestingVault} from "src/interfaces/IVestingVault.sol";

contract VestingVaultMock is IVestingVault {

    address public immutable token;

    constructor(address token_) {
        token = token_;
    }

    function claim() external {

    }

    function depositFor(address recipient, uint amount, uint vestingDuration)
        external
    {

    }

    function vestedFor(address recipient) external view returns (uint) {
        return 0;
    }

    function unvestedFor(address recipient) external view returns (uint) {
        return 0;
    }

}
