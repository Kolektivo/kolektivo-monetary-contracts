// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Interface for owner functionality of the Reserve2
 *
 * @dev This interface declares the onlyOwner functionality for the Reserve2
 *      contract.
 *
 * @author byterocket
 */
interface IReserve2Owner {

    /// @notice Executes a call on a target.
    /// @dev Only callable by owner.
    /// @param target The address to call.
    /// @param data The call data.
    function executeTx(address target, bytes memory data) external;

    function supportERC20(address erc20, address oracle) external;

}
