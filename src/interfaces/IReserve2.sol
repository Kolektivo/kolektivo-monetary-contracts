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

    // @todo Define:
    // - error types
    // - function with docs
    // - structs

    //--------------------------------------------------------------------------
    // Mutating Functions

    /// @notice Returns the current Reserve's status.
    /// @dev Note that this function does not mutate any state in the reserve.
    ///      It is safe to see it as "view".
    /// @return uint Reserve asset's valuation in USD with 18 decimal precision.
    /// @return uint Token supply's valuation in USD with 18 decimal precision.
    /// @return uint BPS of supply backed by reserve.
    function reserveStatus() external returns (uint, uint, uint);

    /// @notice Bonds given amount of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc20 The ERC20 token address.
    /// @param amount The amount of ERC20 tokens to bond.
    function bondERC20(address erc20, uint amount) external;

    /// @notice Bonds given amount of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc20 The ERC20 token address.
    /// @param recipient The recipient address for the reserve tokens.
    /// @param amount The amount of ERC20 tokens to bond.
    function bondERC20For(address erc20, address recipient, uint amount)
        external;

    /// @notice Bonds whole balance of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc20 The ERC20 token address.
    function bondERC20All(address erc20) external;

    /// @notice Bonds whole balance of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc20 The ERC20 token address.
    /// @param recipient The recipient address for the reserve tokens.
    function bondERC20AllFor(address erc20, address recipient) external;

    /// @notice Bonds given ERC721Id instance from caller and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc721Id The ERCC721Id instance.
    function bondERC721Id(ERC721Id memory erc721Id) external;

    /// @notice Bonds given ERC721Id instance from caller and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc721Id The ERCC721Id instance.
    /// @param recipient The recipient address for the reserve tokens.
    function bondERC721IdFor(ERC721Id memory erc721Id, address recipient)
        external;

    /// @notice Unbonds some amount of given ERC20 token to the caller and
    ///         burns given amount of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to unbond.
    /// @param tokenAmount The amount of reserve tokens to burn.
    function unbondERC20(address erc20, uint tokenAmount) external;

    /// @notice Unbonds some amount of given ERC20 token to given recipient and
    ///         burns given amount of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to unbond.
    /// @param recipient The recipient address for the unbonded ERC20 tokens.
    /// @param tokenAmount The amount of reserve tokens to burn.
    function unbondERC20To(
        address erc20,
        address recipient,
        uint tokenAmount
    ) external;

    /// @notice Unbonds some amount of given ERC20 token to the caller and
    ///         burns whole balance of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to unbond.
    function unbondERC20All(address erc20) external;

    /// @notice Unbonds some amount of given ERC20 token to given recipient and
    ///         burns whole balance of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to unbond.
    /// @param recipient The recipient address for the unbonded ERC20 tokens.
    function unbondERC20AllTo(address erc20, address recipient) external;

    /// @notice Unbonds given ERC721Id instance to the caller and burns
    ///         corresponding amount of reserve tokens from the caller.
    /// @param erc721Id The ERC721Id instance.
    function unbondERC721Id(ERC721Id memory erc721Id) external;

    /// @notice Unbonds given ERC721Id instance to given recipient and burns
    ///         corresponding amount of reserve tokens from the caller.
    /// @param erc721Id The ERC721Id instance.
    function unbondERC721IdTo(ERC721Id memory erc721Id, address recipient)
        external;

    //--------------------------------------------------------------------------
    // View Functions

    /// @notice Returns the token address the reserve is backing.
    function token() external view returns (address);

    /// @notice Returns the reserve's token's price oracle address.
    /// @dev Changeable by owner.
    /// @dev Is of type IOracle.
    function tokenOracle() external view returns (address);

    /// @notice Returns the reserve's vesting vault address used for vested
    ///         bonding operations.
    /// @dev Changeable by owner.
    /// @dev Is of type IVestingVault.
    function vestingVault() external view returns (address);

    // @todo supported arrays.

    /// @notice Returns the price oracle for given ERC20 token address.
    /// @param erc20 The ERC20 token address.
    /// @return The ERC20 token's price oracle address of type IOracle.
    function oraclePerERC20(address erc20) external view returns (address);

    /// @notice Returns the price oracle for the ERC721Id instance, identified
    ///         through given hash.
    /// @param erc721IdHash The ERC721Id instance's hash.
    /// @return The ERC721Id instance's price oracle address of type IOracle.
    function oraclePerERC721Id(bytes32 erc721IdHash)
        external
        view
        returns (address);

    //----------------------------------
    // Un/Bonding View Functions

    /// @notice Returns whether the given ERC20 token address is bondable.
    /// @param erc20 The ERC20 token address.
    /// @return Whether the ERC20 token address is bondable.
    function isERC20Bondable(address erc20) external view returns (bool);

    /// @notice Returns whether the ERC721Id instance, identified through
    ///         given hash, is bondable.
    /// @param erc721IdHash The ERC721Id instance's hash
    /// @return Whether the ERC721Id instance is bondable.
    function isERC721IdBondable(bytes32 erc721IdHash)
        external
        view
        returns (bool);

    /// @notice Returns whether the given ERC20 token address is unbondable.
    /// @param erc20 The ERC20 token address.
    /// @return Whether the ERC20 token address is unbondable.
    function isERC20Unbondable(address erc20) external view returns (bool);

    /// @notice Returns whether the ERC721Id instance, identified through given
    ///         hash, is unbondable.
    /// @param erc721IdHash The ERC721Id instance's hash.
    /// @return Whether the ERC721Id instance is unbondable.
    function isERC721IdUnbondable(bytes32 erc721IdHash)
        external
        view
        returns (bool);

    /// @notice Returns the bonding limit for given ERC20 token address.
    /// @dev A limit of zero is treated as infinite, i.e. no limit set.
    /// @param erc20 The ERC20 token address.
    /// @return The bonding limit for given ERC20 token address.
    function bondingLimitPerERC20(address erc20) external view returns (uint);

    /// @notice Returns the unbonding limit for given ERC20 token address.
    /// @param erc20 The ERC20 token address.
    /// @return The unbonding limit for given ERC20 token address.
    function unbondingLimitPerERC20(address erc20) external view returns (uint);

    //----------------------------------
    // Discount View Functions

    /// @notice Returns the discount percentage, denominated in bps, for given
    ///         ERC20 token address.
    /// @param erc20 The ERC20 token address.
    /// @return The discount percentage, denomintated in bps, for given ERC20
    ///         token address.
    function discountPerERC20(address erc20) external view returns (uint);

    /// @notice Returns the discount percentage, denominated in bps, for the
    ///         ERC721Id instance, identified through given hash.
    /// @param erc721IdHash The ERC721Id instance's hash.
    /// @return The discount percentage, denomintated in bps, for given ERc721
    ///         instance.
    function discountPerERC721Id(bytes32 erc721IdHash)
        external
        view
        returns (uint);

    //----------------------------------
    // Vesting View Mappings

    /// @notice Returns the vesting duration for given ERC20 token address.
    /// @param erc20 The ERC20 token address.
    /// @return The vesting duration for given ERC20 token address.
    function vestingDurationPerERC20(address erc20)
        external
        view
        returns (uint);

    /// @notice Returns the vesting duration for the ERC721Id instance,
    ///         identified through given hash.
    /// @param erc721IdHash The ERC721Id instance's hash.
    /// @return The vesting duration for given ERC721Id instance.
    function vestingDurationPerERC721Id(bytes32 erc721IdHash)
        external
        view
        returns (uint);

    //----------------------------------
    // Reserve Management

    /// @notice The minimum backing percentage, denominated in bps, of token
    ///         supply backed by the reserve.
    /// @dev Changeable by owner.
    function minBacking() external view returns (uint);

}
