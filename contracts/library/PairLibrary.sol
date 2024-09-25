// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "hardhat/console.sol";

import "../interface/ITokenPair.sol";

/**
 * @title PairLibrary
 * @dev a library to compute amountIn and amountOut
 * @author Carl Fu
 */
library PairLibrary {
    /**
     * given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
     * @param amountIn the amount of input token
     * @param reserveIn the reserve of input token
     * @param reserveOut the reserve of output token
     */
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "AMMLibrary: INVALID_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "AMMLibrary: INSUFFICIENT_LIQUIDITY"
        );
        /**
         * x * y = k
         * (x + dx * 0.997) * (y - dy) = k = x * y
         * dy = y - ((x * y) / (x + dx * 0.997))
         *    = (y * (x + dx * 0.997) - x * y) / (x + dx * 0.997)
         *    = (y * x + y * dx * 0.997 - x * y) / (x + dx * 0.997)
         *    = (y * dx * 0.997) / (x + dx * 0.997)
         *    = (y * dx * 997) / (x * 1000 + dx * 997)
         * numberator = (y * dx * 997)
         * denominator = (x * 1000 + dx * 997)
         */
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * given an output amount of an asset and pair reserves, returns a required input amount of the other asset
     * @param amountOut the amount of output token
     * @param reserveIn the reserve of input token
     * @param reserveOut the reserve of output token
     */
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, "TokenPairLibrary: INVALID_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "TokenPairLibrary: INSUFFICIENT_LIQUIDITY"
        );
        /**
         * x * y = k
         * (x - dx) * (y + dy * 0.997) = k = x * y
         * dy = (x * y / (x - dx) - y) / 0.997
         *    = (x * y - (x - dx) * y) / (x - dx) / 0.997
         *    = (dx * y) / (x - dx) / 0.997
         *    = (dx * y) / ((x - dx) * 0.997)
         *    = (dx * y * 1000) / ((x - dx) * 997)
         * numberator = (dx * y * 1000)
         * denominator = ((x - dx) * 997)
         */
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * returns sorted token addresses, used to handle return values from pairs sorted in this order
     * @param tokenA token A
     * @param tokenB token B
     * @return token0 the smaller address of token pair
     * @return token1 the larger address of token pair
     */
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "TokenPairLibrary: SAME_ADDRESS");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "TokenPairLibrary: ZERO_ADDRESS");
    }

    /**
     * calculates the CREATE2 address for a pair without making any external calls
     * @param factory pair factory
     * @param tokenA token A
     * @param tokenB token A
     */
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"4035d6e9a6674a11147ef787ef3f4b6f2e7925a4c619fb918e5fdf266ecd77f5"
                        )
                    )
                )
            )
        );
    }

    /**
     * fetches and sorts the reserves for a pair
     * @param factory pair factory
     * @param tokenA token A
     * @param tokenB token B
     * @return reserveA reserve of token A
     * @return reserveB reserve of token B
     */
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = ITokenPair(
            pairFor(factory, tokenA, tokenB)
        ).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    /**
     * given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
     * @param amountA input amount of token A
     * @param reserveA reserve of token A
     * @param reserveB reserve of token B
     */
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "TokenPairLibrary: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "TokenPairLibrary: INSUFFICIENT_LIQUIDITY"
        );
        // A / B = dA / dB
        // dB = dA * B / A
        amountB = (amountA * reserveB) / reserveA;
    }
}
