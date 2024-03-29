// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

contract Initializable {
    bool public initialized;

    constructor(bool testingDeployment) public {
        if (!testingDeployment) {
            initialized = true;
        }
    }

    modifier initializer() {
        require(!initialized, "contract already initialized");
        initialized = true;
        _;
    }
}
