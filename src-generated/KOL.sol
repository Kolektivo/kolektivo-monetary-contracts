// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {TSOwnable} from "../lib/solrocket/src/TSOwnable.sol";
import {Whitelisted} from "../lib/solrocket/src/Whitelisted.sol";

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
contract KOL is ERC20, TSOwnable, Whitelisted {

    // @todo Issue #15 "Not possible to have multiple Reserves mint the same KOL token"
    // If there should be more than one Reserve being eligible to mint KOL
    // tokens the contract's architecture needs to be refactored.
    // - One possibility would be to use a whitelist to grant mint permissions.
    // - If it is clear that ONLY ONE Reserve should ever be allowed to mint
    //   it would be possible to make the Reserve itself the KOL token.

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid token recipient.
    error KOL__InvalidRecipient();

    /// @notice Invalid token amount.
    error KOL__InvalidAmount();

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0) || to == address(this)) {
            revert KOL__InvalidRecipient();
        }
        _;
    }

    /// @dev Modifier to guarantee token amount is valid.
    modifier validAmount(uint amount) {
        if (amount == 0) {
            revert KOL__InvalidAmount();
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
