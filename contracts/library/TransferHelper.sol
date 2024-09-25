// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title TransferHelper
 * @author Carl Fu
 * @notice Contains helper methods for interacting with ERC20 tokens that do not consistently return true/false
 */
library TransferHelper {
    /**
     * Transfers tokens from msg.sender to a recipient
     * @dev Calls transfer on token contract, errors with TF if transfer fails
     * @param token The contract address of the token which will be transferred
     * @param to The recipient of the transfer
     * @param value The value of the transfer
     */
    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TF"
        );
    }

    /**
     * Transfers tokens from sender to a recipient
     * @dev Calls transfer on token contract, errors with TF if transfer fails
     * @param token The contract address of the token which will be transferred
     * @param from The sender of the transfer
     * @param to The recipient of the transfer
     * @param value The value of the transfer
     */
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TF"
        );
    }

    /**
     * Transfers ETH from msg.sender to a recipient
     * @dev Calls transfer on token contract, errors with TF:ETH if transfer fails
     * @param to The recipient of the transfer
     * @param value The value of the transfer
     */
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TF:ETH");
    }
}
