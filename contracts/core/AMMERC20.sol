// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title AMMERC20
 * @dev AMM ERC20 for Token Pair
 * @author Carl Fu
 */
contract AMMERC20 is ERC20 {
    string public constant NAME = "AMM ERC20 for Token Pair";
    string public constant SYMBOL = "AETP";

    constructor() ERC20(NAME, SYMBOL) {}
}
