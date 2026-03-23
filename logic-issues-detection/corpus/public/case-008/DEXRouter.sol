// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DEXRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(deadline >= block.timestamp, 'expired');
        amountOut = amountIn * 97 / 100;
        require(amountOut >= amountOutMin, 'slippage');
    }

    function swapWithPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(block.timestamp >= deadline, 'not ready');
        amountOut = amountIn * 97 / 100;
        require(amountOut >= amountOutMin, 'slippage');
    }
}