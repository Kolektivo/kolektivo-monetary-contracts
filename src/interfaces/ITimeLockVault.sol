// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ITimeLockVault {
    function lock(address token, address receiver, uint256 amount, uint256 duration) external;
    function isLocker(address locker) external view returns (bool);
}
