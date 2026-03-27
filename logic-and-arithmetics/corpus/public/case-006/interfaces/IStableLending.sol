// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStableLending {
    function depositCollateral() external payable;
    function borrow(uint256 amount) external;
    function repay() external payable;
    function withdrawCollateral(uint256 amount) external;
    function collateral(address user) external view returns (uint256);
    function debt(address user) external view returns (uint256);
    function healthFactor(address user) external view returns (uint256);
}
