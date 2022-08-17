// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IVestingVault {

    /// @notice Deposits an amount of tokens that are vested for the recipient
    ///         for given duration.
    function depositFor(address recipient, uint amount, uint duration) external;

    /// @notice Claims any currently vested tokens for msg.sender.
    function claim() external;

    /// @notice Returns the token which is being vested.
    function token() external view returns (address);

    /// @notice Returns the amount of tokens that are currently vested for the receiver.
    function getTotalVestedFor(address receiver) external view returns (uint);

    // @notice Returns amount of tokens that can currently be claimed for the receiver.
    function getTotalClaimableFor(address receiver) external view returns (uint);

    // @notice Returns amount of tokens that are currently locked, but will be claimable later.
    function getTotalNotYetClaimableFor(address receiver) external view returns (uint);

}
