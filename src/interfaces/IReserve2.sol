// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Interface for the public functionality of the Reserve2
 *
 * @dev This interfaces declares the public functionality, struct and error
 *      types, and events for the Reserve2 contract.
 *
 * @author byterocket
 */
interface IReserve2 {

    struct ERC721Id {
        address erc721;
        uint id;
    }

    struct VestedDeposit {
        uint nonEmpty; // solidity: Defining empty struct disallowed.
    }

    // @todo Define:
    // - error types
    // - function with docs
    // - structs

    //--------------------------------------------------------------------------
    // Mutating Functions

    /// @notice Returns the current Reserve's status.
    /// @return uint Reserve asset's valuation in USD with 18 decimal precision.
    /// @return uint Token supply's valuation in USD with 18 decimal precision.
    /// @return uint BPS of supply backed by reserve.
    function reserveStatus() external returns (uint, uint, uint);

    //--------------------------------------------------------------------------
    // View Functions

    /// @notice Returns the token address the reserve is backing.
    function token() external view returns (address);

    /// @notice Returns the reserve's token's price oracle address.
    /// @dev Changeable by owner.
    /// @dev Is of type IOracle.
    function tokenOracle() external view returns (address);

    /// @notice Returns the reserve's vesting vault used for vested bonding
    ///         operations.
    /// @dev Changeable by owner.
    /// @dev Is of type IVestingVault.
    function vestingVault() external view returns (address);

    /// @notice The minimum backing percentage, denominated in bps, of token
    ///         supply backed by the reserve.
    /// @dev Changeable by owner.
    function minBacking() external view returns (uint);

}
