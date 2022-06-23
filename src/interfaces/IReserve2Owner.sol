// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IReserve2} from "./IReserve2.sol";

/**
 * @title Interface for owner functionality of the Reserve2
 *
 * @dev This interface declares the onlyOwner functionality and events emitted
 *      in onlyOwner functions for the Reserve2 contract.
 *
 * @author byterocket
 */
interface IReserve2Owner is IReserve2 {

    //----------------------------------
    // Emergency Functions

    /// @notice Executes a call on a target.
    /// @dev Only callable by owner.
    /// @param target The address to call.
    /// @param data The call data.
    function executeTx(address target, bytes memory data) external;

    //----------------------------------
    // Token Management

    /// @notice Sets the token price oracle.
    /// @dev Only callable by owner.
    /// @param tokenOracle The token's price oracle of type IOracle.
    function setTokenOracle(address tokenOracle) external;

    //----------------------------------
    // Asset Management

    /// @notice Marks given ERC20 token as being supported.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param oracle The ERC20 token's price oracle of type IOracle.
    function supportERC20(address erc20, address oracle) external;

    /// @notice Marks given ERC721Id instance as being supported.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    /// @param oracle The ERC721Id instance's price oracle of type IOracle.
    function supportERC721Id(ERC721Id memory erc721Id, address oracle)
        external;

    /// @notice Marks given ERC20 token as being unsupported.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function unsupportERC20(address erc20) external;

    /// @notice Marks given ERC721Id instance as being unsupported.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    function unsupportERC721Id(ERC721Id memory erc721Id) external;

    /// @notice Updates the price oracle for given ERC20 token.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token.
    /// @param oracle The new token's price oracle of type IOracle.
    function updateOracleForERC20(address erc20, address oracle) external;

    /// @notice Updates the price oracle for given ERC721Id instance.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    /// @param oracle The new ERC721Id instance's price oracle of type IOracle.
    function updateOracleForERC721Id(ERC721Id memory erc721Id, address oracle)
        external;

    //----------------------------------
    // Un/Bonding Management

    /// @notice Marks given ERC20 token as supported for bonding.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function supportERC20ForBonding(address erc20) external;

    /// @notice Marks given ERC721Id instance as supported for bonding.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    function supportERC721IdForBonding(ERC721Id memory erc721Id) external;

    /// @notice Marks given ERC20 token as unsupported for bonding.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function unsupportERC20ForBonding(address erc20) external;

    /// @notice Marks given ERC721Id instance as unsupported for bonding.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    function unsupportERC721IdForBonding(ERC721Id memory erc721Id) external;

    /// @notice Marks given ERC20 token as supported for unbonding.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function supportERC20ForUnbonding(address erc20) external;

    /// @notice Marks given ERC721Id instance as supported for unbonding.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    function supportERC721IdForUnbonding(ERC721Id memory erc721Id) external;

    /// @notice Marks given ERC20 token as unsupported for unbonding.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function unsupportERC20ForUnbonding(address erc20) external;

    /// @notice Marks given ERC721Id instance as unsupported for unbonding.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    function unsupportERC721IdForUnbonding(ERC721Id memory erc721Id) external;

    /// @notice Sets the maximum balance of given ERC20 token allowed in the
    ///         reserve.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param limit The upper balance limit for the ERC20 token.
    function setERC20BondingLimit(address erc20, uint limit) external;

    /// @notice Sets the minimum balance of given ERC20 token allowed in the
    ///         reserve.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param limit The lower balance limit for the ERC20 token.
    function setERC20UnbondingLimit(address erc20, uint limit) external;

    //----------------------------------
    // Discount Management

    /// @notice Sets a discount percentage, denominated in bps, for given ERC20
    ///         token.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param discount The discount for the ERC20 token.
    function setDiscountForERC20(address erc20, uint discount) external;

    /// @notice Sets a discount percentage, denominated in bps, for given
    ///         ERC721Id instance.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    /// @param discount The discount for the ERC721Id instance.
    function setDiscountForERC721Id(ERC721Id memory erc721Id, uint discount)
        external;

    //----------------------------------
    // Vesting Management

    /// @notice Sets the vesting vault to use for vested bondings.
    /// @dev Only callable by owner.
    /// @param vestingVault The vesting vault address of type IVestingVault.
    function setVestingVault(address vestingVault) external;

    /// @notice Sets the vesting duration for given ERC20 token.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param vestingDuration The vesting duration for the ERC20 token.
    function setVestingForERC20(address erc20, uint vestingDuration) external;

    /// @notice Sets the vesting duration for given ERC721Id instance.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    /// @param vestingDuration The vesting duration for the ERC721Id instance.
    function setVestingForERC721Id(
        ERC721Id memory erc721Id,
        uint vestingDuration)
    external;

    //---------------------------------
    // Reserve Management

    /// @notice Sets the minimum backing requirement percentage, denominated
    ///         in bps, for the reserve.
    /// @dev Only callable by owner.
    /// @param minBacking The minimum backing requirement.
    function setMinBacking(uint minBacking) external;

    /// @notice Incurs debt by minting tokens to the caller.
    /// @dev Only callable by owner.
    /// @param amount The amount of tokens to mint.
    function incurDebt(uint amount) external;

    /// @notice Pays debt by burning tokens from the caller.
    /// @dev Only callable by owner.
    /// @param amount The amount of tokens to burn.
    function payDebt(uint amount) external;

}
