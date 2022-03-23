// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "solrocket/Ownable.sol";

contract KOL is ERC20, Ownable {

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Function is only callable by mintBurner.
    error OnlyCallableByMintBurner();

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when mintBurner changed.
    event MintBurnerChanged(address oldMintBurner, address newMintBurner);

    //--------------------------------------------------------------------------
    // Modifiers

    /// @notice Modifier to guarantee function is only callable by mintBurner.
    modifier onlyMintBurner() {
        if (msg.sender != mintBurner) {
            revert OnlyCallableByMintBurner();
        } else {
            _;
        }
    }

    // @todo Create validAmount and validRecipient modifier.

    //--------------------------------------------------------------------------
    // Storage

    /// @notice The mintBurner address with the allowance to mint and burn KOL
    ///         tokens.
    /// @dev Changeable by owner.
    address public mintBurner;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(address mintBurner_)
        ERC20("Kolektivo Reserve Token", "KOL", uint8(18))
    {
        require(
            mintBurner_ != address(this) &&
            mintBurner_ != owner         &&
            mintBurner_ != address(0)
        );
        mintBurner = mintBurner_;
    }

    //--------------------------------------------------------------------------
    // onlyMintBurner Mutating Functions

    /// @notice Mints an amount of KOL tokens to some address.
    /// @dev Only callable by mintBurner.
    function mint(address to, uint amount) external onlyMintBurner {
        super._mint(to, amount);
    }

    /// @notice Burns an amount of KOL tokens from some address.
    /// @dev Only callable by mintBurner.
    function burn(address from, uint amount) external onlyMintBurner {
        super._burn(from, amount);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Mutating Functions

    /// @notice Changes the mintBurner address.
    /// @dev Only callable by owner.
    function setMintBurner(address mintBurner_) external onlyOwner {
        require(
            mintBurner_ != address(this) &&
            mintBurner_ != owner         &&
            mintBurner_ != mintBurner    &&
            mintBurner_ != address(0)
        );

        emit MintBurnerChanged(mintBurner, mintBurner_);
        mintBurner = mintBurner_;
    }

}
