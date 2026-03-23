// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICollateralVault {
    event Deposited(address indexed user, uint256 ethAmount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount, uint256 remainingDebt);
    event Liquidated(address indexed user, address indexed liquidator, uint256 repayAmount, uint256 collateralSeized);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event InterestAccrued(uint256 newIndex, uint256 blocksElapsed);

    error Undercollateralized();
    error PositionHealthy();
    error ExceedsDebt();
    error ZeroAmount();
    error NotOracle();
    error TransferFailed();

    function deposit() external payable;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function liquidate(address user, uint256 repayAmount) external;
    function updatePrice(uint256 newPrice) external;

    function healthFactor(address user) external view returns (uint256);
    function currentDebt(address user) external view returns (uint256);
    function globalInterestIndex() external view returns (uint256);
}
