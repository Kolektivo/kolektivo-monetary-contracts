// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IReserve2 {

    struct ERC721Id {
        address erc721;
        uint id;
    }

    struct VestedDeposit {
        uint nonEmpty; // solidity: Defining empty struct disallowed.
    }

    // @todo Define:
    // - error types
    // - function with docs
    // - structs

}
