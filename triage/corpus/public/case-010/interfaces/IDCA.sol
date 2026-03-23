// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDCA {
    struct Config {
        uint256 interval;
        uint256 amountPerBuy;
        uint256 maxSlippageBps;
    }

    event Configured(address indexed user, uint256 interval, uint256 amountPerBuy);
    event BuyExecuted(address indexed user, uint256 ethSpent, uint256 tokensReceived, uint256 timestamp);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);

    error IntervalTooShort();
    error ZeroAmount();
    error NotReady(address user, uint256 readyAt);
    error InsufficientBalance(address user);
    error BuyFailed();

    function configure(uint256 interval, uint256 amountPerBuy) external;
    function executeBuy(address user) external;
    function withdraw() external;
    function getConfig(address user) external view returns (Config memory);
    function nextBuyTime(address user) external view returns (uint256);
}
