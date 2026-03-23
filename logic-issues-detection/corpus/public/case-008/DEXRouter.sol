// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IDEX.sol";

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

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
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ILiquidityPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract DEXRouter is IDEX {
    address public owner;
    uint256 public feeBps;
    uint256 public accumulatedFees;

    bool private _locked;

    mapping(address => mapping(address => address)) public liquidityPairs;

    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient
    );
    event FeesCollected(uint256 amount);
    event PairRegistered(address tokenA, address tokenB, address pair);
    event FeeBpsUpdated(uint256 newFeeBps);

    error Unauthorized();
    error Reentrant();
    error InvalidPath();
    error SlippageExceeded();
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

    constructor(uint256 _feeBps) {
        owner = msg.sender;
        feeBps = _feeBps;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override nonReentrant returns (uint256 amountOut) {
        require(deadline >= block.timestamp, "expired");
        if (path.length < 2) revert InvalidPath();
        amountOut = amountIn * (10_000 - feeBps) / 10_000;
        if (amountOut < amountOutMin) revert SlippageExceeded();
        uint256 fee = amountIn - amountOut;
        accumulatedFees += fee;
        emit SwapExecuted(path[0], path[path.length - 1], amountIn, amountOut, to);
    }

    function swapWithPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override nonReentrant returns (uint256 amountOut) {
        require(block.timestamp >= deadline, "not ready");
        if (path.length < 2) revert InvalidPath();
        amountOut = amountIn * 97 / 100;
        require(amountOut >= amountOutMin, "slippage");
        emit SwapExecuted(path[0], path[path.length - 1], amountIn, amountOut, to);
    }

    function swapWithPermitAndSig(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 swapDeadline,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant returns (uint256 amountOut) {
        require(block.timestamp <= swapDeadline, "expired");
        if (path.length < 2) revert InvalidPath();
        IERC20Permit(tokenIn).permit(msg.sender, address(this), amountIn, permitDeadline, v, r, s);
        if (!IERC20Permit(tokenIn).transferFrom(msg.sender, address(this), amountIn)) revert TransferFailed();
        amountOut = amountIn * (10_000 - feeBps) / 10_000;
        if (amountOut < amountOutMin) revert SlippageExceeded();
        if (!IERC20Permit(tokenIn).transfer(to, amountOut)) revert TransferFailed();
        emit SwapExecuted(path[0], path[path.length - 1], amountIn, amountOut, to);
    }

    function registerPair(address tokenA, address tokenB, address pair) external onlyOwner {
        liquidityPairs[tokenA][tokenB] = pair;
        liquidityPairs[tokenB][tokenA] = pair;
        emit PairRegistered(tokenA, tokenB, pair);
    }

    function getPairReserves(address tokenA, address tokenB) external view returns (uint112 r0, uint112 r1) {
        address pair = liquidityPairs[tokenA][tokenB];
        require(pair != address(0), "no pair");
        (r0, r1,) = ILiquidityPair(pair).getReserves();
    }

    function collectFees(address token) external onlyOwner {
        uint256 fees = accumulatedFees;
        accumulatedFees = 0;
        if (!IERC20(token).transfer(owner, fees)) revert TransferFailed();
        emit FeesCollected(fees);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "fee too high");
        feeBps = _feeBps;
        emit FeeBpsUpdated(_feeBps);
    }
}
