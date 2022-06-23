// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Interface for the public functionality of the Reserve2
 *
 * @dev This interfaces declares the public functionality, structs and error
 *      types, and events for the Reserve2 contract.
 *
 * @author byterocket
 */
interface IReserve2 {

    /// @notice An ERC721Id defines one specific ERC721 NFT token.
    ///         It is composed of the ERC721 contract address and the token's
    ///         id.
    struct ERC721Id {
        /// @dev The ERC721 contract address.
        address erc721;
        /// @dev The token's id.
        uint id;
    }

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Given token recipient invalid.
    error Reserve2__InvalidRecipient();

    /// @notice Given token amount invalid.
    error Reserve2__InvalidAmount();

    /// @notice Given ERC20 token address not supported.
    error Reserve2__ERC20NotSupported();

    /// @notice Given ERC721Id instance not supported.
    error Reserve2__ERC721IdNotSupported();

    /// @notice Given ERC20 token address not bondable.
    error Reserve2__ERC20NotBondable();

    /// @notice Given ERC721 instance not bondable.
    error Reserve2__ERC721NotBondable();

    /// @notice Given ERC20 token address not unbondable.
    error Reserve2__ERC20NotUnbondable();

    /// @notice Given ERC721 instance not unbondable.
    error Reserve2__ERC721NotUnbondable();

    /// @notice Bonding operation exceeded reserve's bonding limit for given
    ///         ERC20 token address.
    error Reserve2__ERC20BondingLimitExceeded();

    /// @notice Unbonding operation exceeded reserve's unbonding limit for
    ///         given ERC20 token address.
    error Reserve2__ERC20UnbondingLimitExceeded();

    /// @notice Reserve's balance for given ERC20 token address no sufficient.
    error Reserve2__ERC20BalanceNotSufficient();

    /// @notice Reserve's minimum backing limit exceeded.
    error Reserve2__MinimumBackingLimitExceeded();

    /// @notice Reserve received invalid oracle response.
    error Reserve2__InvalidOracle();

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when reserve's backing ratio updated.
    /// @param oldBacking The old backing percentage, denominated in bps.
    /// @param newBacking The new backing percentage, denominated in bps.
    event BackingUpdated(uint oldBacking, uint newBacking);

    /// @notice Event emitted when ERC20 bonding operation succeeded.
    /// @param erc20 The ERC20 token address.
    /// @param erc20sBonded The amount of ERC20 tokens bonded.
    /// @param tokensMinted The amount of reserve tokens minted.
    event BondedERC20(
        address indexed erc20,
        uint erc20sBonded,
        uint tokensMinted
    );

    /// @notice Event emitted when ERC721Id instance bonding operation
    ///         succeeded.
    /// @param erc721Id The ERC721 instance.
    /// @param tokensMinted The amount of reserve tokens minted.
    event BondedERC721(ERC721Id erc721Id, uint tokensMinted);

    /// @notice Event emitted when ERC20 unbonding operation succeeded.
    /// @param erc20 The ERC20 token address.
    /// @param erc20sUnbonded The amount of ERC20 tokens unbonded.
    /// @param tokensBurned The amount of reserve tokens burned.
    event UnbondedERC20(
        address indexed erc20,
        uint erc20sUnbonded,
        uint tokensBurned
    );

    /// @notice Event emitted when ERC721Id instance unbonding operation
    ///         succeeded.
    /// @param erc721Id The ERC721 instance.
    /// @param tokensBurned The amount of reserve tokens burned.
    event UnbondedERC721Id(ERC721Id erc721Id, uint tokensBurned);

    //--------------------------------------------------------------------------
    // Mutating Functions

    //----------------------------------
    // Un/Bonding View Functions

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

    //----------------------------------
    // Reserve Management

    /// @notice Returns the current Reserve's status.
    /// @dev Note that this function does not mutate any state in the reserve.
    ///      It is safe to see it as "view".
    /// @return uint Reserve asset's valuation in USD with 18 decimal precision.
    /// @return uint Token supply's valuation in USD with 18 decimal precision.
    /// @return uint BPS of supply backed by reserve.
    function reserveStatus() external returns (uint, uint, uint);

    //--------------------------------------------------------------------------
    // View Functions

    /// @notice Returns the token address the reserve is backing.
    function token() external view returns (address);

    /// @notice Returns the hash identifier gor given ERC721Id instance.
    /// @param erc721Id The ERC721Id instance.
    /// @return The hash identifier for given ERC721Id instance.
    function hashOfERC721Id(ERC721Id memory erc721Id)
        external
        pure
        returns (bytes32);

    // @todo supported arrays.

    //----------------------------------
    // Vesting View Functions

    /// @notice Returns the reserve's vesting vault address used for vested
    ///         bonding operations.
    /// @dev Changeable by owner.
    /// @dev Is of type IVestingVault.
    function vestingVault() external view returns (address);

    //----------------------------------
    // Oracle View Functions

    /// @notice Returns the reserve's token's price oracle address.
    /// @dev Changeable by owner.
    /// @dev Is of type IOracle.
    function tokenOracle() external view returns (address);

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
