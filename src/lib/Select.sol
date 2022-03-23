// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

// This library is copied from Ampleforth.
// See https://github.com/ampleforth/market-oracle.
library Select {

    /// @dev Computes the median of the first size elements in the array.
    function computeMedian(uint[] memory array, uint size)
        internal
        pure
        returns (uint)
    {
        require(size != 0 && size <= array.length);

        // Sort the array in ascending order.
        for (uint i = 1; i < size; ) {
            for (uint j = i; j > 0 && array[j-1] > array[j]; ) {
                uint tmp = array[j];
                array[j] = array[j-1];
                array[j-1] = tmp;

                unchecked { --j; }
            }

            unchecked { ++i; }
        }

        // Return the median of the first size elements in the array.
        // Note that >> 1 is equal to a division by 2.
        if (size % 2 == 1) {
            return array[size >> 1];
        } else {
            return (array[size >> 1] + array[(size >> 1) - 1] >> 1);
        }
    }

}
