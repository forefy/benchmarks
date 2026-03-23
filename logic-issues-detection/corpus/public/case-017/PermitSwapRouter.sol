// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IDex {
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external returns (uint256 amountOut);
}

contract PermitSwapRouter {
    IDex public immutable dex;

    constructor(address _dex) {
        dex = IDex(_dex);
    }

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
    ) external returns (uint256 amountOut) {
        require(block.timestamp <= swapDeadline, 'swap expired');
        IERC20Permit(tokenIn).permit(msg.sender, address(this), amountIn, permitDeadline, v, r, s);
        IERC20Permit(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        amountOut = dex.swap(tokenIn, tokenOut, amountIn, minAmountOut, msg.sender);
    }
}
