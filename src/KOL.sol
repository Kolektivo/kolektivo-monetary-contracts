// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "solrocket/Ownable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

/**
 * @title KOL Token
 *
 * @dev The KOL ERC20 token is a non-elastic supply token.
 *      A whitelist, managed by the contract's owner, manages mint/burn
 *      permissions for addresses.
 *
 *      The whitelist is necessary to allow different reserves to mint/burn
 *      the KOL token to addresses depositing KTT tokens into that reserve.
 *
 * @author byterocket
 */
contract KOL is ERC20, Ownable, Whitelisted {

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid token recipient.
    error InvalidRecipient();

    /// @notice Invalid token amount.
    error InvalidAmount();

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0) || to == address(this)) {
            revert InvalidRecipient();
        }
        _;
    }

    /// @dev Modifier to guarantee token amount is valid.
    modifier validAmount(uint amount) {
        if (amount == 0) {
            revert InvalidAmount();
        }
        _;
    }
    //--------------------------------------------------------------------------
    // Constructor

    constructor() ERC20("Kolektivo Reserve Token", "KOL", uint8(18)) {
        // NO-OP
    }

    //--------------------------------------------------------------------------
    // onlyWhitelisted Mutating Functions

    /// @notice Mints an amount of KOL tokens to some address.
    /// @dev Only callable by whitelisted address.
    function mint(address to, uint amount) external onlyWhitelisted {
        super._mint(to, amount);
    }

    /// @notice Burns an amount of KOL tokens from some address.
    /// @dev Only callable by whitelisted address.
    function burn(address from, uint amount) external onlyWhitelisted {
        super._burn(from, amount);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Mutating Functions

    /// @notice Adds an address to the whitelist for being eligible for
    ///         mint/burn operations.
    /// @dev Only callable by owner.
    /// @param who The address to add to the whitelist.
    function addToWhitelist(address who) external onlyOwner {
        super._addToWhitelist(who);
    }

    /// @notice Removes an address from the whitelist from being eligible for
    ///         mint/burn operations.
    /// @dev Only callable by owner.
    /// @param who The address to remove from the whitelist.
    function removeFromWhitelist(address who) external onlyOwner {
        super._removeFromWhitelist(who);
    }

    //--------------------------------------------------------------------------
    // Overriden ERC20 Mutating Functions
    //
    // Note that the functions are overidden in order to enforce the validAmount
    // and validRecipient modifiers.

    function approve(address spender, uint amount)
        public
        override(ERC20)
        validRecipient(spender)
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    function transfer(address to, uint amount)
        public
        override(ERC20)
        validRecipient(to)
        validAmount(amount)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint amount)
        public
        override(ERC20)
        validRecipient(to)
        validAmount(amount)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

}
