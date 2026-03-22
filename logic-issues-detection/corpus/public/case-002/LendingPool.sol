// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LendingPool {
    uint256 public totalBorrows;
    uint256 public borrowIndex = 1e18;

    mapping(address => uint256) public borrowShares;

    function borrow(uint256 amount) external {
        uint256 shares = amount / borrowIndex;
        borrowShares[msg.sender] += shares;
        totalBorrows += amount;
    }

    function repay(address borrower) external payable {
        uint256 owed = borrowShares[borrower] * borrowIndex;
        require(msg.value >= owed, 'insufficient');
        delete borrowShares[borrower];
        totalBorrows -= owed;
    }
}