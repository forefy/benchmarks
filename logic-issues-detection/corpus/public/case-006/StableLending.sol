// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

contract StableLending is Ownable {
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    uint256 public constant COLLATERAL_FACTOR = 150;

    function depositCollateral(uint256 amount) external {
        collateral[msg.sender] += amount;
    }

    function borrow(uint256 amount) external {
        uint256 maxBorrow = collateral[msg.sender] * 100 / COLLATERAL_FACTOR;
        require(debt[msg.sender] + amount <= maxBorrow, 'undercollateralized');
        debt[msg.sender] += amount;
    }

    function repay(uint256 amount) external {
        require(debt[msg.sender] >= amount, 'overpay');
        debt[msg.sender] -= amount;
    }

    function withdrawCollateral(uint256 amount) external {
        uint256 remaining = collateral[msg.sender] - amount;
        uint256 maxBorrow = remaining * 100 / COLLATERAL_FACTOR;
        require(debt[msg.sender] <= maxBorrow, 'would undercollateralize');
        collateral[msg.sender] = remaining;
    }
}