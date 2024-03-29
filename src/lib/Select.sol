// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

/**
 * @title Select Library
 *
 * @dev Provides functionality to compute the median of a set of uints.
 *
 * @author Ampleforth
 * @author byterocket
 */
library Select {
    /// @notice Computes the median of the first size elements in the array.
    function computeMedian(uint256[] memory array, uint256 size) internal pure returns (uint256) {
        require(size != 0 && size <= array.length);

        // Sort the array in ascending order.
        for (uint256 i = 1; i < size;) {
            for (uint256 j = i; j > 0 && array[j - 1] > array[j];) {
                uint256 tmp = array[j];
                array[j] = array[j - 1];
                array[j - 1] = tmp;

                unchecked {
                    --j;
                }
            }

            unchecked {
                ++i;
            }
        }

        // Return the median of the first size elements in the array.
        // Note that >> 1 is equal to a division by 2.
        if (size % 2 == 1) {
            return array[size >> 1];
        } else {
            // Note that an average computation of (a + b) / 2 could overflow.
            // Therefore the computation is distributed:
            //      (a / 2) + (b / 2) + (((a % 2) + (b % 2)) / 2).
            uint256 a = array[size >> 1];
            uint256 b = array[(size >> 1) - 1];

            return (a >> 1) + (b >> 1) + (((a % 2) + (b % 2)) >> 1);
        }
    }
}
