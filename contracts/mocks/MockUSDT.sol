// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("mock usdt", "MUSDT") {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
