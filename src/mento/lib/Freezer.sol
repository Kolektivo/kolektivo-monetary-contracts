// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.10;

import "@oz-up/access/OwnableUpgradeable.sol";
import "./IFreezer.sol";

contract Freezer is OwnableUpgradeable, IFreezer {
    mapping(address => bool) public isFrozen;

    /**
     * @notice Sets initialized == true on implementation contracts
     * @param isImplementation Set to true to lock he initialization
     */
    constructor(bool isImplementation) {
        if (isImplementation) _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    /**
     * @notice Freezes the target contract, disabling `onlyWhenNotFrozen` functions.
     * @param target The address of the contract to freeze.
     */
    function freeze(address target) external onlyOwner {
        isFrozen[target] = true;
    }

    /**
     * @notice Unfreezes the contract, enabling `onlyWhenNotFrozen` functions.
     * @param target The address of the contract to freeze.
     */
    function unfreeze(address target) external onlyOwner {
        isFrozen[target] = false;
    }
}
