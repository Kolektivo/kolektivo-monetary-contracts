// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/**
 * @title Time-locked Vault
 *
 * @dev TODO: change description
 *      Investors can vest the same receiver multiple times,
 *      vested tokens are unlocked gradually over time period specified by investor.
 *
 *      Note that feeOnTransfer and rebasing tokens are NOT supported.
 *
 * @author byterocket
 */
contract TimeLockVault {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Types

    /// @dev Lock encapsulates time-locked token metadata.
    struct Lock {
        address token;
        uint256 amount;
        uint256 unlockAt;
    }

    //--------------------------------------------------------------------------
    // Storage

    /// @dev Mapping of receiver address to Lock struct array.
    mapping(address => Lock[]) private _locks;

    /// @dev Addresses that are allowed to create locks
    mapping(address => bool) private _lockers;

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when tokens are time-locked.
    event Locked(address indexed receiver, address indexed token, uint256 amount, uint256 unlockAt);
    /// @notice Event emitted when receiver claims unlocked tokens.
    event Claimed(address indexed receiver, address indexed token, uint256 amount);

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid token receiver.
    error InvalidRecipient();

    /// @notice Invalid token amount.
    error InvalidAmount();

    /// @notice Invalid vesting duration.
    error InvalidDuration();

    /// @notice Receiver has no locks.
    error UserHasNoLocks();

    /// @notice Sender is not eligible to create a lock
    error SenderCantLock();

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee that only certain addresses may create locks
    modifier validSender() {
        if (!_lockers[msg.sender]) {
            revert SenderCantLock();
        }
        _;
    }

    /// @dev Modifier to guarantee token receiver is valid.
    modifier validRecipient(address receiver, address token) {
        if (receiver == address(0) || receiver == address(this) || receiver == msg.sender || receiver == address(token))
        {
            revert InvalidRecipient();
        }
        _;
    }

    /// @dev Modifier to guarantee token amount is valid.
    modifier validAmount(uint256 amount) {
        if (amount == 0 || amount > 10e40) {
            revert InvalidAmount();
        }
        _;
    }

    /// @dev Modifier to guarantee lock duration is valid.
    modifier validDuration(uint256 duration) {
        // @notice duration cap is 10e8 (roughly 31 years)
        if (duration == 0 || duration > 10e8) {
            revert InvalidDuration();
        }
        _;
    }

    /// @dev Modifier to guarantee receiver has active vestings assigned to him.
    modifier hasActiveLocks(address receiver) {
        if (_locks[receiver].length == 0) {
            revert UserHasNoLocks();
        }
        _;
    }

    //--------------------------------------------------------------------------
    // External Functions

    /// @notice Create new vesting by depositing tokens.
    /// @notice Vesting starts immediately.
    /// @param receiver Address to receive the vesting.
    /// @param amount Amount of tokens to be deposited.
    /// @param duration Length of time over which tokens are vested.
    function lock(address token, address receiver, uint256 amount, uint256 duration)
        external
        validSender
        validRecipient(receiver, token)
        validAmount(amount)
        validDuration(duration)
    {
        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 unlockAt = block.timestamp + duration;

        // @dev save vesting to storage
        Lock memory newLock = Lock(token, amount, unlockAt);

        _locks[receiver].push(newLock);

        emit Locked(receiver, token, amount, unlockAt);
    }

    /// @notice Release all unlocked tokens to receiver.
    function claim() external hasActiveLocks(msg.sender) {
        uint256 amountOfLocks = _locks[msg.sender].length;
        for (uint256 i; i < amountOfLocks; ++i) {
            if (_tryUnlock(i)) {
                amountOfLocks--;
                i--;
            }
        }
    }

    /// @notice Release all unlocked tokens to receiver of a token
    function claimToken(address token) external hasActiveLocks(msg.sender) {
        uint256 amountOfLocks = _locks[msg.sender].length;
        for (uint256 i; i < amountOfLocks; ++i) {
            if (_locks[msg.sender][i].token == token && _tryUnlock(i)) {
                amountOfLocks--;
                i--;
            }
        }
    }

    /// @notice Release one specific lock
    function claimAt(uint256 index) external hasActiveLocks(msg.sender) {
        _tryUnlock(index);
    }

    /// @notice Internal function that releases a certain lock if it's due
    function _tryUnlock(uint256 index) internal returns (bool) {
        Lock memory thisLock = _locks[msg.sender][index];
        if (block.timestamp >= thisLock.unlockAt) {
            // If this lock is not the last one
            if (index != _locks[msg.sender].length - 1) {
                // Replace the current one with the last one
                _locks[msg.sender][index] = _locks[msg.sender][_locks[msg.sender].length - 1];
            }
            // Delete lock and decrease cached length and current index
            _locks[msg.sender].pop();

            ERC20(thisLock.token).safeTransfer(msg.sender, thisLock.amount);
            emit Claimed(msg.sender, thisLock.token, thisLock.amount);
            return true;
        }
        return false;
    }

    //--------------------------------------------------------------------------
    // External view Functions

    /// @notice Returns all locks for receiver address.
    /// @param receiver Address of user to query.
    /// @return locks   Array of the receivers active locks.
    function getLocksOf(address receiver) external view hasActiveLocks(receiver) returns (Lock[] memory locks) {
        return _locks[receiver];
    }

    /// @notice Returns whether an address is a whitelisted locker
    /// @param locker Address to check.
    /// @return A boolean indicating whether the address is a locker.
    function isLocker(address locker) external view returns (bool) {
        return _lockers[locker];
    }
}
