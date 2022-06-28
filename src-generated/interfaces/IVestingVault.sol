// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IVestingVault {

    /// @notice Deposits an amount of tokens that are vested for the recipient
    ///         for given duration.
    function depositFor(
        address recipient,
        uint amount,
        uint vestingDuration
    ) external;

    /// @notice Claims any currently vested tokens for msg.sender.
    function claim() external;

    /// @notice Returns the token which is being vested.
    function token() external view returns (address);

    /// @notice Returns the amount of tokens that are currently vested for
    ///         the recipient.
    function vestedFor(address recipient) external view returns (uint);

    /// @notice Returns the amunt of token that are currently unvested,
    ///         i.e. claimable, for the recipient.
    function unvestedFor(address recipient) external view returns (uint);

}
