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
    // Events

    /// @notice Event emitted when investor deposits tokens.
    event DepositFor(address indexed investor, address indexed receiver, uint amount, uint duration);
    /// @notice Event emitted when receiver withdraws vested tokens.
    event Claim(address indexed receiver, uint withdrawnAmount);

    //--------------------------------------------------------------------------
    // Storage

    /// @dev _token will use ERC20.sol
    ERC20 private immutable _token;

    /// @dev Mapping of recipient address to Vesting struct array.
    mapping(address => Vesting[]) private _vestings;

    //--------------------------------------------------------------------------
    // Constructor

    /// @param token Token address used for vesting.
    constructor(address token) {
        require(token != address(0), "token cant be 0x0");
        require(token != msg.sender, "token cant be same as sender");
        require(token.code.length != 0, "token cant be 0 length");

        _token = ERC20(token);
    }

    //--------------------------------------------------------------------------
    // External Functions

    // TODO use modifiers + reverts instead of require statements
    /// @notice Create new vesting by depositing tokens.
    /// @notice Vesting starts immediately.
    /// @param recipient Address to receive the vesting.
    /// @param amount Amount of tokens to be deposited.
    /// @param duration Length of time over which tokens are vested.
    function depositFor(address recipient, uint amount, uint duration) external {
        require(recipient != address(0), "invalid recipient");
        require(recipient != msg.sender, "receiver cant be sender");
        require(recipient != address(_token), "receiver cant be token");
        require(amount > 0, "amount cant be 0");
        require(duration > 0, "duration cant be 0");

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

    // TODO replace require statement w modifier
    /// @notice Release all claimable tokens to caller.
    function claim() external {
        require(_vestings[msg.sender].length > 0, "sender has no vestings available");

        uint totalClaimable;
        for(uint vestingSlot; vestingSlot < _vestings[msg.sender].length; ++vestingSlot){
            Vesting memory vesting = _vestings[msg.sender][vestingSlot];
            // @dev if vesting is finished and nothing is claimed, everything is available
            if(vesting.alreadyReleased == 0 && block.timestamp > vesting.end){
                totalClaimable += vesting.totalAmount;
                delete vesting;
            }
            // @dev if not everything is released yet, use regular calculation
            if(vesting.totalAmount > vesting.alreadyReleased){
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
    function getTokenAddress() external view returns (address) {
        return address(_token);
    }

    /// NOTE vestings that are already drained are deleted, therefore not accounted for.
    /// @notice Returns sum of all vestings for receiver address.
    /// @param receiver Address of user to query.
    /// @return uint Amount of vested tokens for specified address.
    function getTotalVestedFor(address receiver) external view returns (uint) {
        require(_vestings[receiver].length > 0, "receiver has no vestings available");

        uint totalVestedFor;
        for(uint vestingSlot; vestingSlot < _vestings[receiver].length; ++vestingSlot){
            totalVestedFor += _vestings[receiver][vestingSlot].totalAmount;
        }

        return totalVestedFor;
    }

    // TODO replace single require with modifier ?
    /// @notice Returns amount of tokens that can currently be claimed for specified address.
    /// @param receiver Address of user to query.
    /// @return uint Amount of tokens that can currently be claimed.
    function getTotalClaimableAmount(address receiver) external view returns (uint) {
        require(_vestings[receiver].length > 0, "receiver has no vestings available");

        uint totalClaimable;
        for(uint vestingSlot; vestingSlot < _vestings[receiver].length; ++vestingSlot){
          Vesting memory vesting = _vestings[receiver][vestingSlot];
          // @dev if not everything is released yet, use regular calculation
          if(vesting.totalAmount > vesting.alreadyReleased){
              uint timePassed = block.timestamp - vesting.start;
              uint totalDuration = vesting.end - vesting.start;
              totalClaimable += timePassed * vesting.totalAmount / totalDuration
              - vesting.alreadyReleased;
          }
          // @dev if vesting is finished and nothing is claimed, everything is available
          if(vesting.alreadyReleased == 0 && block.timestamp > vesting.end){
              totalClaimable += vesting.totalAmount;
          }
        }

        return totalClaimable;
    }

    /// @notice Returns amount of tokens that are still locked,
    ///         but will be available for claiming in the future for specified address.
    /// @param receiver Address of user to query.
    /// @return uint Amount of tokens that will be available for claiming in the future.
    function getTotalNotYetClaimableAmount(address receiver) external view returns (uint) {
        require(_vestings[receiver].length > 0, "receiver has no vestings available");

        uint totalNonClaimable;
        for(uint vestingSlot; vestingSlot < _vestings[receiver].length; ++vestingSlot){
            Vesting memory vesting = _vestings[receiver][vestingSlot];
            // @dev if vesting is currently ongoing (not finished), use regular calculation
            if(block.timestamp < vesting.end){
                uint timeRemaining = vesting.end - block.timestamp;
                uint totalDuration = vesting.end - vesting.start;

                totalNonClaimable += vesting.totalAmount / totalDuration * timeRemaining;
            }
            // TODO remove following case after testing as it is almost impossible;
            // only if called the same second as depositFor().
            if(block.timestamp == vesting.start)
                totalNonClaimable += vesting.totalAmount;
        }

        return totalNonClaimable;
    }
}
