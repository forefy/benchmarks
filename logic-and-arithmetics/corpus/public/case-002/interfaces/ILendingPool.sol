// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingPool {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(address borrower) external payable;
    function totalBorrows() external view returns (uint256);
    function borrowShares(address account) external view returns (uint256);
    function getBorrowBalance(address borrower) external view returns (uint256);
    function utilizationRate() external view returns (uint256);
}
