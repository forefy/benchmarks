// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISwapRouter.sol";

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
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IDex {
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external returns (uint256 amountOut);
    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256);
}

contract PermitSwapRouter is ISwapRouter {
    IDex public immutable dex;
    address public owner;
    uint256 public feeBps;
    uint256 public accumulatedFees;
    bool private _locked;

    event SwapExecuted(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event MultiHopSwapExecuted(address indexed user, address[] path, uint256 amountIn, uint256 amountOut);
    event FeesCollected(address indexed token, uint256 amount);
    event FeeBpsUpdated(uint256 newFeeBps);

    error Unauthorized();
    error Reentrant();
    error SwapExpired();
    error SlippageExceeded();
    error InvalidPath();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _dex, uint256 _feeBps) {
        dex = IDex(_dex);
        owner = msg.sender;
        feeBps = _feeBps;
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
    ) external override nonReentrant returns (uint256 amountOut) {
        require(block.timestamp <= swapDeadline, "swap expired");
        IERC20Permit(tokenIn).permit(msg.sender, address(this), amountIn, permitDeadline, v, r, s);
        IERC20Permit(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        amountOut = dex.swap(tokenIn, tokenOut, amountIn, minAmountOut, msg.sender);
        if (amountOut < minAmountOut) revert SlippageExceeded();
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function swapExact(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external override nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert SwapExpired();
        if (!IERC20Permit(tokenIn).transferFrom(msg.sender, address(this), amountIn)) revert TransferFailed();
        uint256 fee = amountIn * feeBps / 10_000;
        accumulatedFees += fee;
        uint256 amountInAfterFee = amountIn - fee;
        amountOut = dex.swap(tokenIn, tokenOut, amountInAfterFee, minAmountOut, msg.sender);
        if (amountOut < minAmountOut) revert SlippageExceeded();
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function multiHopSwap(
        address[] calldata path,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert SwapExpired();
        if (path.length < 2) revert InvalidPath();
        if (!IERC20Permit(path[0]).transferFrom(msg.sender, address(this), amountIn)) revert TransferFailed();
        uint256 currentAmount = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            address recipient = i == path.length - 2 ? msg.sender : address(this);
            currentAmount = dex.swap(path[i], path[i + 1], currentAmount, 0, recipient);
        }
        amountOut = currentAmount;
        if (amountOut < minAmountOut) revert SlippageExceeded();
        emit MultiHopSwapExecuted(msg.sender, path, amountIn, amountOut);
    }

    function quoteSwap(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        return dex.getAmountOut(tokenIn, tokenOut, amountIn);
    }

    function collectFees(address token) external onlyOwner {
        uint256 fees = accumulatedFees;
        accumulatedFees = 0;
        if (!IERC20Permit(token).transfer(owner, fees)) revert TransferFailed();
        emit FeesCollected(token, fees);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 300, "fee too high");
        feeBps = _feeBps;
        emit FeeBpsUpdated(_feeBps);
    }
}
