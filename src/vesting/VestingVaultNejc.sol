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
 * @dev ...
 *      Note that feeOnTransfer and rebasing tokens are NOT supported.
 *
 * @author byterocket
 */
contract VestingVault {
    using SafeTransferLib for ERC20;

    ERC20 private immutable _token;

    struct Vesting {
        uint start;
        uint end;
        uint totalAmount;
        uint alreadyReleased;
    }

    // recipientAddress => Vesting
    mapping(address => Vesting[]) private _vestings;

    constructor(address token) {
        require(token != address(0), "token cant be 0x0");
        require(token != msg.sender, "token cant be same as sender");
        require(token.code.length != 0, "token cant be 0 length");

        _token = ERC20(token);
    }

    //--------------------------------------------------------------------------
    // External Functions

    // TODO use modifiers + reverts instead of require statements
    function depositFor(address recipient, uint amount, uint duration) external {
        require(recipient != address(0), "invalid recipient");
        require(recipient != msg.sender, "receiver cant be sender");
        require(recipient != address(_token), "receiver cant be token");
        require(amount > 0, "amount cant be 0");
        require(duration > 0, "duration cant be 0");

        _token.safeTransferFrom(msg.sender, address(this), amount);

        // Create a new Vesting instance.
        Vesting memory vesting = Vesting(
            block.timestamp,                   // start
            block.timestamp + duration,        // end
            amount,                            // totalAmount
            0                                  // alreadyReleased
        );

        // Push new Vesting instance to recipient's vesting array.
        _vestings[recipient].push(vesting);

          // TODO emit event
    }

    // @notice release all available tokens for caller
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

        require(totalClaimable > 0, "nothing to witdraw");

        _token.safeTransfer(msg.sender, totalClaimable);

        // TODO emit event
    }

    //--------------------------------------------------------------------------
    // External view Functions

    function getTokenAddress() external view returns (address) {
        return address(_token);
    }

    function getTotalVestedFor(address receiver) external view returns (uint) {
        require(_vestings[receiver].length > 0, "receiver has no vestings available");

        uint totalVestedFor;
        for(uint vestingSlot; vestingSlot < _vestings[receiver].length; ++vestingSlot){
            totalVestedFor += _vestings[receiver][vestingSlot].totalAmount;
        }

        return totalVestedFor;
    }

    // TODO replace single require with modifier ?
    function getTotalClaimableAmount(address receiver) external view returns (uint) {
        require(_vestings[receiver].length > 0, "receiver has no vestings available");

        uint totalClaimable;
        for(uint vestingSlot; vestingSlot < _vestings[receiver].length; ++vestingSlot){
          Vesting memory vesting = _vestings[receiver][vestingSlot];
          // @dev if not everything is released yet, use regular calculation
          if(vesting.totalAmount > vesting.alreadyReleased){
              uint timePassed = block.timestamp - vesting.start;
              uint totalDuration = vesting.end - vesting.start;
              totalClaimable += timePassed * vesting.totalAmount / totalDuration - vesting.alreadyReleased;
          }
          // @dev if vesting is finished and nothing is claimed, everything is available
          if(vesting.alreadyReleased == 0 && block.timestamp > vesting.end){
              totalClaimable += vesting.totalAmount;
          }
        }

        return totalClaimable;
    }

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
