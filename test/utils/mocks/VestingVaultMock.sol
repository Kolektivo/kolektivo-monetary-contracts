// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {IERC20} from "src/interfaces/_external/IERC20.sol";

import {IVestingVault} from "src/interfaces/IVestingVault.sol";

contract VestingVaultMock is IVestingVault {

    address public immutable token;

    struct Vesting {
        uint timestamp;
        uint amount;
    }

    mapping(address => Vesting) private vestings;

    constructor(address token_) {
        token = token_;
    }

    function claim() external {
        Vesting storage v = vestings[msg.sender];

        if (v.timestamp >= block.timestamp) {
            IERC20(token).transfer(msg.sender, v.amount);
        }
    }

    function depositFor(address recipient, uint amount, uint vestingDuration)
        external
    {
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        Vesting memory v = Vesting(block.timestamp + vestingDuration, amount);

        vestings[recipient] = v;
    }

    function vestedFor(address recipient) external view returns (uint) {
        return 0;
    }

    function unvestedFor(address recipient) external view returns (uint) {
        return 0;
    }

}
