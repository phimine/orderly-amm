// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "hardhat/console.sol";

import "../interface/IAMMRouter.sol";
import "../interface/IWETH.sol";
import "../interface/ITokenPair.sol";
import "../interface/ITokenPairFactory.sol";
import "../library/PairLibrary.sol";
import "../library/TransferHelper.sol";

contract AMMRouter is
    IAMMRouter,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    /////////////////////////
    /*  Type Declarations  */
    /////////////////////////

    /////////////////////////
    /*   State Variables   */
    /////////////////////////
    address public factory;
    address public WETH;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    /////////////////////////
    /*       Events        */
    /////////////////////////

    /////////////////////////
    /*      Modifiers      */
    /////////////////////////

    /////////////////////////
    /*     Constructor     */
    /////////////////////////
    function initialize(address _factory, address _WETH) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);

        factory = _factory;
        WETH = _WETH;
    }

    /////////////////////////
    /*      Functions      */
    /////////////////////////
    //////////////// receive ////////////////
    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    /////////////// external ////////////////
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to
    )
        external
        payable
        virtual
        override
        returns (uint amountToken, uint amountETH, uint liquidity)
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = PairLibrary.pairFor(factory, token, WETH);
        console.log("the PairLibrary.pairFor return is", pair);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = ITokenPair(pair).mint(to);
        // refund eth if any dust
        if (msg.value > amountETH) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        }
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to
    ) external override returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this)
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB) {
        address pair = PairLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransfer(pair, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = ITokenPair(pair).burn(to);
        (address token0, ) = PairLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(amountA >= amountAMin, "AMMRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "AMMRouter: INSUFFICIENT_B_AMOUNT");
    }

    /**
     * swap to get ERC20 tokens using exact ETH
     * @param amountOutMin The minimum output amount
     * @param token the other token address of pair
     * @param to the receiver
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address token,
        address to
    ) external payable override returns (uint256[] memory amounts) {
        (uint256 reserve0, uint256 reserve1) = PairLibrary.getReserves(
            factory,
            WETH,
            token
        );

        uint256 amountOut = PairLibrary.getAmountOut(
            msg.value,
            reserve0,
            reserve1
        );
        require(
            amountOut >= amountOutMin,
            "AMMRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWETH(WETH).deposit{value: msg.value}();
        assert(
            IWETH(WETH).transfer(
                PairLibrary.pairFor(factory, WETH, token),
                msg.value
            )
        );
        _swap(amountOut, WETH, token, to);

        amounts[0] = msg.value;
        amounts[1] = amountOut;
    }

    /**
     * swap to get exact ERC20 tokens using ETH
     * @param amountOut The exact output amount
     * @param token the other token address of pair
     * @param to the receiver
     */
    function swapETHForExactTokens(
        uint256 amountOut,
        address token,
        address to
    ) external payable override returns (uint256[] memory amounts) {
        (uint256 reserve0, uint256 reserve1) = PairLibrary.getReserves(
            factory,
            WETH,
            token
        );
        uint256 amountIn = PairLibrary.getAmountIn(
            amountOut,
            reserve0,
            reserve1
        );

        require(amountIn <= msg.value, "AMMRouter: EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit{value: amountIn}();
        assert(
            IWETH(WETH).transfer(
                PairLibrary.pairFor(factory, WETH, token),
                amountIn
            )
        );
        _swap(amountOut, WETH, token, to);
        // refund extra eth if any
        if (msg.value > amounts[0]) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
        }

        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    /**
     * swap to get ETH using exact ERC20 tokens
     * @param amountIn The exact input amount
     * @param amountOutMin The minimum output amount
     * @param token the other ERC20 token of pair
     * @param to the receiver
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address to
    ) external override returns (uint256[] memory amounts) {
        (uint256 reserve0, uint256 reserve1) = PairLibrary.getReserves(
            factory,
            token,
            WETH
        );
        uint256 amountOut = PairLibrary.getAmountOut(
            amountIn,
            reserve0,
            reserve1
        );
        require(
            amountOut >= amountOutMin,
            "AMMRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            PairLibrary.pairFor(factory, token, WETH),
            amountIn
        );
        _swap(amountOut, token, WETH, address(this));
        IWETH(WETH).withdraw(amountIn);
        TransferHelper.safeTransferETH(to, amountIn);

        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    /**
     * swap to get exact ETH using ERC20 tokens
     * @param amountOut The exact output amount
     * @param amountInMax The max input amount
     * @param token the other ERC20 token of pair
     * @param to the receiver
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address token,
        address to
    ) external override returns (uint256[] memory amounts) {
        (uint256 reserve0, uint256 reserve1) = PairLibrary.getReserves(
            factory,
            token,
            WETH
        );
        uint256 amountIn = PairLibrary.getAmountIn(
            amountOut,
            reserve0,
            reserve1
        );
        require(amountIn <= amountInMax, "AMMRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            PairLibrary.pairFor(factory, token, WETH),
            amounts[0]
        );
        _swap(amountOut, token, WETH, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);

        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    //////////////// internal ////////////////
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADE_ROLE) {}

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (ITokenPairFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ITokenPairFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = PairLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            // initial liquidity
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = PairLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "AMMRouter: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = PairLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "AMMRouter: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _swap(
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        address _to
    ) internal {
        (address token0, ) = PairLibrary.sortTokens(tokenIn, tokenOut);
        (uint amount0Out, uint amount1Out) = tokenIn == token0
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        ITokenPair(PairLibrary.pairFor(factory, tokenIn, tokenOut)).swap(
            amount0Out,
            amount1Out,
            _to
        );
    }
}
