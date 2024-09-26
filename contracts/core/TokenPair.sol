// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interface/ITokenPair.sol";
import "../library/Math.sol";
import "../library/TransferHelper.sol";
import "./AMMERC20.sol";
import "./TokenPairFactory.sol";

/**
 * @title TokenPair
 * @author Carl Fu
 * @notice The token pair only support swaping between ETH and ERC20
 * @dev 1. mint LP token when provide liquidity
 *      2. burn LP token when remove liquidity
 *      3. swap ETH/ERC20（ERC20->ETH、 ETH->ERC20）
 */
contract TokenPair is AMMERC20, ITokenPair {
    /////////////////////////
    /*  Type Declarations  */
    /////////////////////////
    using Math for uint256;

    /////////////////////////
    /*   State Variables   */
    /////////////////////////
    address public factory;
    address public token0;
    address public token1;

    // use single storage slot
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    bool private locked = false;

    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));
    uint256 internal constant BASE_DECIMAL = 10 ** 8;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    // the address to lock minimum liquidity
    address public constant lockAddress =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /////////////////////////
    /*       Events        */
    /////////////////////////
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    /////////////////////////
    /*       Errors        */
    /////////////////////////
    error TokenPair__mint__INSUFFICIENT_LIQUIDITY();
    error TokenPair__burn__INSUFFICIENT_LIQUIDITY();
    error TokenPair__swap__INSUFFICIENT_OUTPUT_AMOUNT();
    error TokenPair__swap__INSUFFICIENT_LIQUIDITY();
    error TokenPair__swap__INVALID_TO();
    error TokenPair__swap__INSUFFICIENT_INPUT_AMOUNT();

    /////////////////////////
    /*      Modifiers      */
    /////////////////////////
    /**
     * lock modifier to avoid reentrance attack.
     */
    modifier lock() {
        require(!locked, "TokenPair: LOCKED");
        locked = true;
        _;
        locked = false;
    }

    /**
     * only allows valid swap amout
     */
    modifier validSwap(uint256 amount0, uint256 amount1) {
        if (amount0 <= 0 && amount1 <= 0) {
            revert TokenPair__swap__INSUFFICIENT_OUTPUT_AMOUNT();
        }
        _;
    }

    /////////////////////////
    /*     Constructor     */
    /////////////////////////
    constructor() {
        factory = msg.sender;
    }

    /////////////////////////
    /*      Functions      */
    /////////////////////////
    /////// external ////////
    /**
     * initialize the token pair
     * @dev only allow factory to initialize, errors with FORBIDDEN if not factory
     * @param _token0 token0 address
     * @param _token1 token1 address
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "TokenPair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * get the current reserve of token0/token1
     * @dev use single storage slot to storage the group of variables
     * @return reserve0 reserve of token0
     * @return reserve1 reserve of token1
     * @return blockTimestampLast timestamp of last update
     */
    function getReserves()
        public
        view
        override
        returns (uint112, uint112, uint32)
    {
        return (reserve0, reserve1, blockTimestampLast);
    }

    /**
     * mint LP token when provide liquidity
     * @dev errors with INSUFFICIENT_LIQUIDITY_MINTED if too low liquidity provided
     * @param to the LP token receiver
     */
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = (amount0 * amount1).sqrt() - MINIMUM_LIQUIDITY;
            _mint(lockAddress, MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }
        if (liquidity <= 0) {
            revert TokenPair__mint__INSUFFICIENT_LIQUIDITY();
        }
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint256(reserve0) * reserve1; // k = x * y

        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * burn LP token when remove liquidity
     * @dev errors with INSUFFICIENT_LIQUIDITY_BURNED if too low liquidity
     * @param to the pair tokens receiver
     */
    function burn(
        address to
    ) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        uint256 _totalSupply = totalSupply();
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        if (amount0 <= 0 || amount1 <= 0) {
            revert TokenPair__burn__INSUFFICIENT_LIQUIDITY();
        }
        _burn(address(this), liquidity);
        TransferHelper.safeTransfer(_token0, to, amount0);
        TransferHelper.safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint256(reserve0) * reserve1;

        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * swap ETH/ERC20（ERC20->ETH、 ETH->ERC20）
     * @dev errors with INSUFFICIENT_LIQUIDITY if too low liquidity
     * @param amount0Out the output amount needed of token0
     * @param amount1Out the output amount needed of token1
     * @param to tokens receiver
     */
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external lock validSwap(amount0Out, amount1Out) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        if (amount0Out > _reserve0 || amount1Out > _reserve1) {
            revert TokenPair__swap__INSUFFICIENT_LIQUIDITY();
        }

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            if (to == _token0 || to == _token1) {
                revert TokenPair__swap__INVALID_TO();
            }
            if (amount0Out > 0)
                TransferHelper.safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0)
                TransferHelper.safeTransfer(_token1, to, amount1Out);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out
            ? balance0 - (_reserve0 - amount0Out)
            : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out
            ? balance1 - (_reserve1 - amount1Out)
            : 0;
        if (amount0In == 0 && amount1In == 0) {
            revert TokenPair__swap__INSUFFICIENT_INPUT_AMOUNT();
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /////// internal ////////
    /**
     * update the price cumulative for TWAP
     * @param balance0 current reserve of token0
     * @param balance1 current reserve of token1
     * @param _reserve0 previous reserve of token0
     * @param _reserve1 previous reserve of token1
     */
    function _update(
        uint balance0,
        uint balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) internal {
        require(
            balance0 <= type(uint112).max && balance1 <= type(uint112).max,
            "TokenPair: OVERFLOW"
        );
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast +=
                uint256((BASE_DECIMAL * _reserve1) / _reserve0) *
                timeElapsed;
            price1CumulativeLast +=
                uint256((BASE_DECIMAL * _reserve0) / _reserve1) *
                timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }
}
