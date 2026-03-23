// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// Lending protocol where users deposit collateral and borrow against it.
// Liquidators repay the borrow and receive collateral at a 5% bonus.
contract LendingMarket {
    IERC20 public collateral;
    IERC20 public debt;

    mapping(address => uint256) public deposited;
    mapping(address => uint256) public borrowed;

    uint256 public constant LTV = 75;
    uint256 public constant LIQUIDATION_BONUS = 105;

    function deposit(uint256 amount) external {
        collateral.transferFrom(msg.sender, address(this), amount);
        deposited[msg.sender] += amount;
    }

    function borrow(uint256 amount) external {
        uint256 maxBorrow = (deposited[msg.sender] * LTV) / 100;
        require(borrowed[msg.sender] + amount <= maxBorrow, "undercollateralized");
        borrowed[msg.sender] += amount;
        debt.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        debt.transferFrom(msg.sender, address(this), amount);
        borrowed[msg.sender] -= amount;
    }

    function forceClose(address user, uint256 repayAmount) external {
        require(borrowed[user] > 0, "no debt");
        debt.transferFrom(msg.sender, address(this), repayAmount);
        borrowed[user] -= repayAmount;
        uint256 collateralSeized = (repayAmount * LIQUIDATION_BONUS) / 100;
        deposited[user] -= collateralSeized;
        collateral.transfer(msg.sender, collateralSeized);
    }
}
