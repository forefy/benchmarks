// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PriceRouter {
    address public immutable owner;
    address public dex;

    uint256 public constant MAX_SLIPPAGE_BPS = 1000;

    mapping(address => uint256) public twapPrices;

    event DexUpdated(address indexed oldDex, address indexed newDex);
    event TwapUpdated(address indexed token, uint256 price);

    error Unauthorized();
    error ZeroAddress();
    error SlippageExceeded(uint256 expected, uint256 actual, uint256 maxBps);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address _dex) {
        if (_dex == address(0)) revert ZeroAddress();
        owner = msg.sender;
        dex = _dex;
    }

    function updateDex(address newDex) external onlyOwner {
        if (newDex == address(0)) revert ZeroAddress();
        emit DexUpdated(dex, newDex);
        dex = newDex;
    }

    function updateTwap(address token, uint256 price) external onlyOwner {
        twapPrices[token] = price;
        emit TwapUpdated(token, price);
    }

    function validateSlippage(
        address token,
        uint256 amountOut,
        uint256 ethIn,
        uint256 maxSlippageBps
    ) external view {
        uint256 twap = twapPrices[token];
        if (twap == 0) return;
        uint256 expected = ethIn * twap / 1e18;
        if (expected == 0) return;
        uint256 slippage = expected > amountOut
            ? ((expected - amountOut) * 10000) / expected
            : 0;
        if (slippage > maxSlippageBps) revert SlippageExceeded(expected, amountOut, maxSlippageBps);
    }

    function getExpectedOut(address token, uint256 ethIn) external view returns (uint256) {
        uint256 twap = twapPrices[token];
        if (twap == 0) return 0;
        return ethIn * twap / 1e18;
    }
}
