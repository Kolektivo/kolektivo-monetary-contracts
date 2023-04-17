// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {IERC20Metadata} from "../interfaces/_external/IERC20Metadata.sol";

/**
 * @title Wad Library
 *
 * @dev Provides functionality to convert ERC20 token amounts between wad
 *      format, i.e. 18 decimal precision, and the ERC20's native decimal
 *      precision format.
 *
 * @author byterocket
 */
library Wad {
    /// @notice Returns the amount in wad format, i.e. 18 decimal precision.
    function convertToWad(address erc20, uint256 amount) internal view returns (uint256) {
        uint256 decimals = IERC20Metadata(erc20).decimals();

        if (decimals == 18) {
            // No decimal adjustment neccessary.
            return amount;
        }

        if (decimals < 18) {
            // If erc20 has less than 18 decimals, move amount by difference of
            // decimal precision to the left.
            return amount * 10 ** (18 - decimals);
        } else {
            // If erc20 has more than 18 decimals, move amount by difference of
            // decimal precision to the right.
            return amount / 10 ** (decimals - 18);
        }
    }

    /// @notice Returns the amount in the ERC20's decimals precision format.
    /// @dev Expects the amount to be in wad format, i.e. 18 decimal precision.
    function convertFromWad(address erc20, uint256 amount) internal view returns (uint256) {
        uint256 decimals = IERC20Metadata(erc20).decimals();

        if (decimals == 18) {
            // No decimal adjustment neccessary.
            return amount;
        }

        if (decimals < 18) {
            // If erc20 has less than 18 decimals, move amount by difference of
            // decimal precision to the right.
            return amount / 10 ** (18 - decimals);
        } else {
            // If erc20 has more than 18 decimals, move amount by difference of
            // decimal precision to the left.
            return amount * 10 ** (decimals - 18);
        }
    }
}
