// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

// External Interfaces.
import {IERC20} from "../interfaces/_external/IERC20.sol";

// External Contracts.
import {ERC20} from "solmate/tokens/ERC20.sol";

// External Libraries.
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/**
 * @title Vesting Vault
 *
 * @dev
 *      Investors can vest the same receiver multiple times,
 *      vested tokens are unlocked gradually over time period specified by investor.
 *
 *      Note that feeOnTransfer and rebasing tokens are NOT supported.
 *
 * @author byterocket
 */
contract VestingVault {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Types

    /// @dev Vesting encapsulates vesting metadata.
    struct Vesting {
        uint start;
        uint end;
        uint totalAmount;
        uint alreadyReleased;
    }


    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid token recipient.
    error InvalidRecipient();

    /// @notice Invalid token amount.
    error InvalidAmount();

    /// @notice Invalid vesting duration.
    error InvalidVestingDuration();

    /// @notice receiver has no active vestings.
    error InvalidVestingsData();

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when investor deposits tokens.
    event DepositFor(address indexed investor, address indexed receiver, uint amount, uint duration);
    /// @notice Event emitted when receiver withdraws vested tokens.
    event Claim(address indexed receiver, uint withdrawnAmount);

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0)      ||
            to == address(this)   ||
            to == msg.sender      ||
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

    /// @dev Modifier to guarantee receiver has active vestings assigned to him.
    modifier validVestingData(address receiver) {
        if (_vestings[receiver].length == 0) {
            revert InvalidVestingsData();
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Storage

    /// @dev _token will use ERC20.sol
    ERC20 private immutable _token;

    /// @dev Mapping of receiver address to Vesting struct array.
    mapping(address => Vesting[]) private _vestings;

    //--------------------------------------------------------------------------
    // Constructor

    /// @param token_ Token address used for vesting.
    constructor(address token_) {
        require(token_ != address(0), "token cant be 0x0");
        require(token_ != msg.sender, "token cant be same as sender");
        require(token_.code.length != 0, "token cant be 0 length");

        _token = ERC20(token_);
    }

    //--------------------------------------------------------------------------
    // External Functions

    /// @notice Create new vesting by depositing tokens.
    /// @notice Vesting starts immediately.
    /// @param recipient Address to receive the vesting.
    /// @param amount Amount of tokens to be deposited.
    /// @param duration Length of time over which tokens are vested.
    function depositFor(address recipient, uint amount, uint duration)
        external
        virtual
        validRecipient(recipient)
        validAmount(amount)
        validVestingDuration(duration)
    {
        _token.safeTransferFrom(msg.sender, address(this), amount);

        Vesting memory vesting = Vesting(
            block.timestamp,                   // start
            block.timestamp + duration,        // end
            amount,                            // totalAmount
            0                                  // alreadyReleased
        );
        _vestings[recipient].push(vesting);

        emit DepositFor(msg.sender, recipient, amount, duration);
    }

    /// @notice Release all claimable tokens to caller.
    function claim() external virtual validVestingData (msg.sender) {
        uint totalClaimable;
        for(uint slot; slot < _vestings[msg.sender].length; ++slot){
            Vesting memory vesting = _vestings[msg.sender][slot];
            // @dev if vesting is finished and nothing is claimed, everything is available
            if(vesting.alreadyReleased == 0 && block.timestamp > vesting.end){
                totalClaimable += vesting.totalAmount;
                delete vesting;
            }
            // @dev if not everything is released yet, use regular calculation
            else {
                uint timePassed = block.timestamp - vesting.start;
                uint totalDuration = vesting.end - vesting.start;
                uint claimableAmount = timePassed * vesting.totalAmount / totalDuration
                - vesting.alreadyReleased;

                vesting.alreadyReleased += claimableAmount;
                totalClaimable += claimableAmount;

                if(vesting.alreadyReleased == vesting.totalAmount)
                    delete vesting;
            }
        }

        require(totalClaimable > 0, "nothing to claim");

        _token.safeTransfer(msg.sender, totalClaimable);

        emit Claim(msg.sender, totalClaimable);
    }

    //--------------------------------------------------------------------------
    // External view Functions

    /// @notice Returns address of token used for vesting.
    /// @return address Vesting token address.
    function token() external view returns (address) {
        return address(_token);
    }

    /// @notice Returns sum of all vestings for receiver address.
    /// @param receiver Address of user to query.
    /// @return uint Amount of vested tokens for specified address.
    function getTotalVestedFor(address receiver)
        external
        virtual
        validVestingData(receiver)
        view
        returns (uint)
    {
        uint totalVestedFor;
        for(uint slot; slot < _vestings[receiver].length; ++slot){
            totalVestedFor += _vestings[receiver][slot].totalAmount;
        }

        return totalVestedFor;
    }

    /// @notice Returns amount of tokens that can currently be claimed for specified address.
    /// @param receiver Address of user to query.
    /// @return uint Amount of tokens that can currently be claimed.
    function getTotalClaimableFor(address receiver)
        external
        virtual
        validVestingData(receiver)
        view
        returns (uint)
    {
        uint totalClaimable;
        for(uint slot; slot < _vestings[receiver].length; ++slot){
            Vesting memory vesting = _vestings[receiver][slot];
            // @dev if vesting is finished and nothing is claimed, everything is available
            if(vesting.alreadyReleased == 0 && block.timestamp > vesting.end){
                totalClaimable += vesting.totalAmount;

            // @dev if not everything is released yet, use regular calculation
          }else if(vesting.totalAmount > vesting.alreadyReleased){
                uint timePassed = block.timestamp - vesting.start;
                uint totalDuration = vesting.end - vesting.start;

                totalClaimable += timePassed * vesting.totalAmount / totalDuration
                - vesting.alreadyReleased;
            }
        }

        return totalClaimable;
    }

    /// @notice Returns receivers amount of tokens that are still locked,
    ///         but will be available for claiming in the future.
    /// @param receiver Address of user to query.
    /// @return uint Amount of tokens that will be available for claiming later.
    function getTotalNotYetClaimableFor(address receiver)
        external
        virtual
        validVestingData(receiver)
        view
        returns (uint)
    {
        uint totalNonClaimable;
        for(uint slot; slot < _vestings[receiver].length; ++slot){
            Vesting memory vesting = _vestings[receiver][slot];
            // @dev if vesting is currently ongoing (not finished), use regular calculation
            if(block.timestamp < vesting.end){
                uint timeRemaining = vesting.end - block.timestamp;
                uint totalDuration = vesting.end - vesting.start;

                totalNonClaimable += vesting.totalAmount * timeRemaining / totalDuration;
            }
        }

        return totalNonClaimable;
    }
}
