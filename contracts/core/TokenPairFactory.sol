// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

import "../interface/ITokenPairFactory.sol";
import "../interface/ITokenPair.sol";
import "./TokenPair.sol";

/**
 * @title TokenPairFactory
 * @dev the factory to manage token pair
 * @author Carl Fu
 */
contract TokenPairFactory is ITokenPairFactory {
    /////////////////////////
    /*  Type Declarations  */
    /////////////////////////

    /////////////////////////
    /*   State Variables   */
    /////////////////////////
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    /////////////////////////
    /*       Events        */
    /////////////////////////
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    /////////////////////////
    /*      Modifiers      */
    /////////////////////////

    /////////////////////////
    /*     Constructor     */
    /////////////////////////
    constructor() {}

    /////////////////////////
    /*      Functions      */
    /////////////////////////
    /**
     * get the total length of all existing pairs
     */
    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    /**
     * create token pair
     * @dev errors with SAME_ADDRESSES if both token are the same,
     * error with ZERO_ADDRESS if one token is 0x00,
     * error with PAIR_EXISTS if token pair already exists
     * @param tokenA token0
     * @param tokenB token1
     * @return pair pair contract address
     */
    function createPair(
        address tokenA,
        address tokenB
    ) external override returns (address pair) {
        require(tokenA != tokenB, "TokenPairFactory: SAME_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "TokenPairFactory: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "TokenPairFactory: PAIR_EXISTS"
        );
        bytes memory bytecode = type(TokenPair).creationCode;
        console.logBytes32(keccak256(bytecode));
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ITokenPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        console.log("the pair created in factory is", pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
