// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

// External Interfaces.
import {IERC20} from "../interfaces/_external/IERC20.sol";

// External Contracts.
import {ERC20} from "solmate/tokens/ERC20.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";

// External Libraries.
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// Internal Interfaces.
import {IVestingVault} from "../interfaces/IVestingVault.sol";

/**
 * @title Vesting Vault
 *
 * @dev ...
 *      Note that feeOnTransfer and rebasing tokens are NOT supported.
 *
 * @author byterocket
 */
contract VestingVault is TSOwnable {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid token recipient.
    error InvalidRecipient();

    /// @notice Invalid token amount.
    error InvalidAmount();

    /// @notice Invalid vesting duration.
    error InvalidVestingDuration();

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0)      ||
            to == address(this)   ||
            to == address(_token)
        ) {
            revert InvalidRecipient();
        }
        _;
    }

    /// @dev Modifier to guarantee token amount is valid.
    modifier validAmount(uint amount) {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _;
    }

    /// @dev Modifier to guarantee vesting duration is valid.
    modifier validVestingDuration(uint vestingDuration) {
        if (vestingDuration == 0) {
            revert InvalidVestingDuration();
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Types

    struct Vesting {
        uint start;
        uint end;
        uint totalAmount;
        uint alreadyReleased;
    }

    //--------------------------------------------------------------------------
    // Storage

    ERC20 private immutable _token;

    // user:
    // vesting A: 100 token, 100 days
    // After 50 days
    // vesting B: 200 tokens, 50 days

    // user => array of vesting instances.
    mapping(address => Vesting[]) private _vestingsPerAddress;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(address token) {
        require(token != address(0));
        require(token.code.length != 0);

        _token = ERC20(token);
    }

    //--------------------------------------------------------------------------
    // IVestingVault Mutating Functions

    function depositFor(address recipient, uint amount, uint vestingDuration)
        external
        validRecipient(recipient)
        validAmount(amount)
        validVestingDuration(vestingDuration)
    {
        // Fetch tokens.
        // Note that FoT and rebasing tokens are NOT supported.
        _token.safeTransferFrom(msg.sender, address(this), amount);

        // Create a new Vesting instance.
        Vesting memory vesting = Vesting(
            block.timestamp,                   // start
            block.timestamp + vestingDuration, // end
            amount,                            // totalAmount
            0                                  // alreadyReleased
        );

        // Push new Vesting instance to recipient's vesting array.
        _vestingsPerAddress[recipient].push(vesting);
    }

    function release() external {
        uint[] memory releasables = _releasables(msg.sender);

        Vesting[] storage vestings = _vestingsPerAddress[msg.sender];

        // @todo Remove after tests!
        assert(releasables.length == vestings.length);

        uint sum;
        uint deleted;

        uint len = releasables.length;
        for (uint i; i < len; ++i) {

            // Add releasable amount to sum.
            sum += releasables[i];

            // If vesting expired, delete instance and continue loop.
            if (vestings[i].end <= block.timestamp) {
                // Override current vesting with last, not yet copied, vesting.
                vestings[i] = vestings[vestings.length - 1 - deleted];

                // Increase deleted vestings counter.
                unchecked {
                    ++deleted;
                }

                // @todo If this breaks, we do not release all tokens.
                assert(vestings[i].totalAmount == vestings[i].alreadyReleased + releasables[i]);

                continue;
            }

            // Adjust vesting's alreadyReleased field if vesting already
            // (and still) active.
            if (vestings[i].start <= block.timestamp) {
                vestings[i].alreadyReleased += releasables[i];

                // @todo Remove after enough testing.
                assert(vestings[i].alreadyReleased < vestings[i].totalAmount);
            }
        }

        // Delete expired vestings.
        for (uint i; i < deleted; ++i) {
            vestings.pop();
        }

        // Send tokens to recipient.
        _token.safeTransfer(msg.sender, sum);
    }

    //--------------------------------------------------------------------------
    // IVestingVault View Functions

    function releasable(address recipient) external view returns (uint) {
        uint[] memory releasables = _releasables(recipient);

        uint sum;
        uint len = releasables.length;
        for (uint i; i < len; ++i) {
            sum += releasables[i];
        }

        return sum;
    }

    function token() external view returns (address) {
        return address(_token);
    }

    //--------------------------------------------------------------------------
    // Internal Functions

    /// @dev Returns an array of token amounts releasable for given recipient.
    ///      The array has the same length and order as the Vesting instances
    ///      array of the given recipient.
    function _releasables(address recipient) internal view returns (uint[] memory) {
        Vesting[] memory vestings = _vestingsPerAddress[recipient];

        // Array of releasable tokens in same order as the recipient's Vesting
        // array.
        uint[] memory releasables = new uint[](vestings.length);

        // Loop variables declared outside of loop to save gas.
        Vesting memory vesting;
        uint currentDuration;
        uint totalDuration;

        uint len = vestings.length;
        for (uint i; i < len; ++i) {
            vesting = vestings[i];

            // If no time passed since the start of the vesting, the releasable
            // amount is zero.
            if (block.timestamp <= vesting.start) {
                releasables[i] = 0;

                continue;
            }

            // If vesting's end not yet reached, compute and store the current
            // releasable amount.
            if (block.timestamp < vesting.end) {
                currentDuration = block.timestamp - vesting.start;
                totalDuration = vesting.end - vesting.start;

                releasables[i] =
                    ((vesting.totalAmount * currentDuration) / totalDuration) // Total amount releasable
                    - vesting.alreadyReleased;                  // Substract already released amount

                continue;
            }

            // Otherwise the vesting deadline expired and all tokens are
            // releasable.
            releasables[i] = vesting.totalAmount - vesting.alreadyReleased;
        }

        return releasables;
    }

}
