// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interface/IWETH.sol";

contract MockWETH is ERC20, IWETH {
    constructor() ERC20("mock weth", "MWETH") {}

    function deposit() external payable override {
        uint256 amount = msg.value;
        _mint(msg.sender, amount);
    }

    function transfer(
        address to,
        uint value
    ) public override(ERC20, IWETH) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function withdraw(uint256 _amount) external override {
        payable(msg.sender).transfer(_amount);
    }
}
