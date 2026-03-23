// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingMarket {
    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event ForceClosed(
        address indexed user,
        address indexed liquidator,
        uint256 repayAmount,
        uint256 collateralSeized
    );
    event OracleUpdated(address indexed newOracle);

    error ZeroAmount();
    error ExceedsMaxBorrow();
    error NoDebt();
    error NotOwner();

    function deposit(uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function forceClose(address user, uint256 repayAmount) external;

    function healthFactor(address user) external view returns (uint256);
    function maxBorrow(address user) external view returns (uint256);
    function currentUtilization() external view returns (uint256);
}
