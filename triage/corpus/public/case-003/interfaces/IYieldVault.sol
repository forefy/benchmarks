// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IYieldVault {
    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 assets, uint256 fee);
    event Harvested(uint256 profit, uint256 fee);
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event EmergencyExitTriggered(address indexed by);

    error ZeroAmount();
    error EmergencyMode();
    error NotOwner();

    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function harvest() external;
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function setStrategy(address newStrategy) external;
    function triggerEmergencyExit() external;
}
