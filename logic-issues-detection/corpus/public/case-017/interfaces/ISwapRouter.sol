// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISwapRouter {
    function swapWithPermit(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 swapDeadline,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountOut);

    function swapExact(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);
}
