// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {TSOwnable} from "solrocket/TSOwnable.sol";

/**
 * @title Reserve Token
 *
 * @dev The Reserve ERC20 token is a vanilla ERC20 token with a mintBurner
 *      role that is eligible to perform mint and burn operations.
 *
 *      The mintBurner role is managed by the contracts owner.
 *
 * @author byterocket
 */
contract ReserveToken is ERC20, TSOwnable {
    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid token recipient.
    error ReserveToken__InvalidRecipient();

    /// @notice Invalid token amount.
    error ReserveToken__InvalidAmount();

    /// @notice Function is only callable by mintBurner.
    error ReserveToken__NotMintBurner();

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when a mintBurner address is updated.
    /// @param mintBurner The mintBurner address.
    /// @param newStatus The new status of the mintBurner (true = active).
    event UpdateMintBurner(address indexed mintBurner, bool newStatus);

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0) || to == address(this)) {
            revert ReserveToken__InvalidRecipient();
        }
        _;
    }

    /// @dev Modifier to guarantee token amount is valid.
    modifier validAmount(uint256 amount) {
        if (amount == 0) {
            revert ReserveToken__InvalidAmount();
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable by mintBurner.
    modifier onlyMintBurner() {
        if (!mintBurner[msg.sender]) {
            revert ReserveToken__NotMintBurner();
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Storage

    /// @notice The addresses that are eligible for mint and burn operations.
    /// @dev Changeable by owner.
    mapping(address => bool) public mintBurner;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(string memory name, string memory symbol) ERC20(name, symbol, uint8(18)) {}

    //--------------------------------------------------------------------------
    // onlyWhitelisted Mutating Functions

    /// @notice Mints an amount of KOL tokens to some address.
    /// @dev Only callable by mintBurner address.
    function mint(address to, uint256 amount) external validRecipient(to) validAmount(amount) onlyMintBurner {
        super._mint(to, amount);
    }

    /// @notice Burns an amount of KOL tokens from some address.
    /// @dev Only callable by mintBurner address.
    function burn(address from, uint256 amount) external validAmount(amount) onlyMintBurner {
        super._burn(from, amount);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Mutating Functions

    /// @notice Sets the mintBurner address.
    /// @dev Only callable by owner.
    function setMintBurner(address who, bool status) external onlyOwner {
        if (mintBurner[who] != status) {
            emit UpdateMintBurner(who, status);
            mintBurner[who] = status;
        }
    }

    //--------------------------------------------------------------------------
    // Overriden ERC20 Mutating Functions
    //
    // Note that the functions are overidden in order to enforce the validAmount
    // and validRecipient modifiers.

    function approve(address spender, uint256 amount) public override (ERC20) validRecipient(spender) returns (bool) {
        return super.approve(spender, amount);
    }

    function transfer(address to, uint256 amount)
        public
        override (ERC20)
        validRecipient(to)
        validAmount(amount)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override (ERC20)
        validRecipient(to)
        validAmount(amount)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }
}
