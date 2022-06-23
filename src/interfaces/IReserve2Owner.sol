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

    //--------------------------------------------------------------------------
    // Events

    //----------------------------------
    // Oracle Management

    /// @notice Event emitted when token's price oracle set.
    /// @param oldOracle The token's old price oracle.
    /// @param newOracle The token's new price oracle.
    event SetTokenOracle(address indexed oldOracle, address indexed newOracle);

    /// @notice Event emitted when ERC20 token's price oracle set.
    /// @param erc20 The ERC20 token address.
    /// @param oldOracle The ERC20 token's old price oracle.
    /// @param newOracle The ERC20 token's new price oracle.
    event SetERC20Oracle(
        address indexed erc20,
        address indexed oldOracle,
        address indexed newOracle
    );

    /// @notice Event emitted when ERC721Id instance's price oracle set.
    /// @param erc721Id The ERC721Id instance.
    /// @param oldOracle The ERC721Id instance's old price oracle.
    /// @param newOracle The ERC721Id instance's new price oracle.
    event SetERC721IdOracle(
        ERC721Id indexed erc721Id,
        address indexed oldOracle,
        address indexed newOracle
    );

    //----------------------------------
    // Asset Management

    /// @notice Event emitted when ERC20 token address marked as supported.
    /// @param erc20 The ERC20 token address.
    event ERC20MarkedAsSupported(address indexed erc20);

    /// @notice Event emitted when ERC721 instance marked as supported.
    /// @param erc721Id The ERC721 instance.
    event ERC721IdMarkedAsSupported(ERC721Id indexed erc721Id);

    /// @notice Event emitted when ERC20 token addres marked as unsupported.
    /// @param erc20 The ERC20 token address.
    event ERC20MarkedAsUnsupported(address indexed erc20);

    /// @notice Event emitted when ERC721Id instance marked as unsupported.
    /// @param erc721Id The ERC721Id instance.
    event ERC721IdMarkedAsUnsupported(ERC721Id indexed erc721Id);

    //----------------------------------
    // Un/Bonding Management

    /// @notice Event emitted when ERC20 token's support for bonding set.
    /// @param erc20 The ERC20 token address.
    /// @param support Whether the ERC20 token is supported or unsupported for
    ///                bonding.
    event SetERC20BondingSupport(address indexed erc20, bool support);

    /// @notice Event emitted when ERC721Id instance's support for bonding set.
    /// @param erc721Id The ERC721Id instance.
    /// @param support Whether the ERC721Id instance is supported or
    ///                unsupported for bonding.
    event SetERC721IdBondingSupport(
        ERC721Id indexed erc721Id,
        bool support
    );

    /// @notice Event emitted when ERC20 token's support for unbonding set.
    /// @param erc20 The ERC20 token address.
    /// @param support Whether the ERC20 token is supported or unsupported for
    ///                bonding.
    event SetERC20UnbondingSupport(address indexed erc20, bool support);

    /// @notice Event emitted when ERC721Id instance's support for unbonding
    ///         set.
    /// @param erc721Id The ERC721Id instance.
    /// @param support Whether the ERC721Id instance is supported or
    ///                unsupported for unbonding.
    event SetERC721IdUnbondingSupport(
        ERC721Id indexed erc721Id,
        bool support
    );

    /// @notice Event emitted when ERC20 token's bonding limit set.
    /// @param erc20 The ERC20 token address.
    /// @param oldLimit The ERC20 token's old bonding limit.
    /// @param newLimit The ERC20 token's new bonding limit.
    event SetERC20BondingLimit(
        address indexed erc20,
        uint oldLimit,
        uint newLimit
    );

    /// @notice Event emitted when ERC20 token's unbonding limit set.
    /// @param erc20 The ERC20 token address.
    /// @param oldLimit The ERC20 token's old unbonding limit.
    /// @param newLimit The ERC20 token's new unbonding limit.
    event SetERC20UnbondingLimit(
        address indexed erc20,
        uint oldLimit,
        uint newLimit
    );

    //----------------------------------
    // Discount Management

    /// @notice Event emitted when ERC20 token's discount set.
    /// @param erc20 The ERC20 token's address.
    /// @param oldDiscount The ERC20 token's old discount.
    /// @param newDiscount The ERC20 token's new discount.
    event SetERC20Discount(
        address indexed erc20,
        uint oldDiscount,
        uint newDiscount
    );

    /// @notice Event emitted when ERC721Id instance's discount set.
    /// @param erc721Id The ERC721Id instance.
    /// @param oldDiscount The ERC721Id instance's old discount.
    /// @param newDiscount The ERC721Id instance's new discount.
    event SetERC721IdDiscount(
        ERC721Id indexed erc721Id,
        uint oldDiscount,
        uint newDiscount
    );


    //----------------------------------
    // Vesting Management

    /// @notice Event emitted when vesting vault address set.
    /// @param oldVestingVault The old vesting vault's address.
    /// @param newVestingVault The new vesting vault's address.
    event SetVestingVault(
        address indexed oldVestingVault,
        address indexed newVestingVault
    );

    /// @notice Event emitted when ERC20 token's vesting duration set.
    /// @param erc20 The ERC20 token's address.
    /// @param oldVestingDuration The ERC20 token's old vesting duration.
    /// @param newVestingDuration The ERC20 token's new vesting duration.
    event SetERC20Vesting(
        address indexed erc20,
        uint oldVestingDuration,
        uint newVestingDuration
    );

    /// @notice Event emitted when ERC721Id instance's vesting duration set.
    /// @param erc721Id The ERC721Id instance.
    /// @param oldVestingDuration The ERC721Id instance's old vesting duration.
    /// @param newVestingDuration The ERC721Id instance's new vesting duration.
    event SetERC721IdVesting(
        ERC721Id indexed erc721Id,
        uint oldVestingDuration,
        uint newVestingDuration
    );

    //----------------------------------
    // Reserve Management

    /// @notice Event emitted when the reserve's minimum backing requirement
    ///         set.
    /// @param oldMinBacking The old minimum backing requirement percentage,
    ///                      denominated in bps.
    /// @param newMinBacking The new minimum backing requirement percentage,
    ///                      denominated in bps.
    event SetMinBacking(uint oldMinBacking, uint newMinBacking);

    /// @notice Event emitted when new debt incurred.
    /// @param tokenAmount The amount of tokens incurred as new debt.
    event DebtIncurred(uint tokenAmount);

    /// @notice Event emitted when debt payed.
    /// @param tokenAmount The amount of token payed as debt.
    event DebtPayed(uint tokenAmount);

    //--------------------------------------------------------------------------
    // Functions

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
    function supportERC721Id(
        ERC721Id memory erc721Id,
        address oracle
    ) external;

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
    function updateOracleForERC721Id(
        ERC721Id memory erc721Id,
        address oracle
    ) external;

    //----------------------------------
    // Un/Bonding Management

    /// @notice Marks given ERC20 token as supported or unsupported for bonding.
    /// @dev ERC20 token must be supported already.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param support Whether the ERC20 token should be supported or
    ///                unsupported for bonding.
    function supportERC20ForBonding(address erc20, bool support) external;

    /// @notice Marks given ERC721Id instance as supported or unsupported for
    ///         bonding.
    /// @dev ERC721 instance must be supported already.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    /// @param support Whether the ERC721Id instance should be supported or
    ///                unsupported for bonding.
    function supportERC721IdForBonding(
        ERC721Id memory erc721Id,
        bool support
    ) external;

    /// @notice Marks given ERC20 token as supported or unsupported for
    ///         unbonding.
    /// @dev ERC20 token must be supported already.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param support Whether the ERC20 token should be supported or
    ///                unsupported for bonding.
    function supportERC20ForUnbonding(address erc20, bool support) external;

    /// @notice Marks given ERC721Id instance as supported or unsupported for
    ///         unbonding.
    /// @dev ERC721 instance must be supported already.
    /// @dev Only callable by owner.
    /// @param erc721Id The ERC721Id instance.
    /// @param support Whether the ERC721Id instance should be supported or
    ///                unsupported for bonding.
    function supportERC721IdForUnbonding(
        ERC721Id memory erc721Id,
        bool support
    ) external;

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
    function setDiscountForERC721Id(
        ERC721Id memory erc721Id,
        uint discount
    ) external;

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
        uint vestingDuration
    ) external;

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
