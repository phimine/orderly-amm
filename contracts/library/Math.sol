// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Math
 * @dev a library for performing various math operations
 * @author Carl Fu
 */
library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    /**
     * z = √y
     * @param y y
     */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
