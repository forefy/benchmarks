// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IFlashLoan.sol";

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract LoanReceiver is IFlashBorrower {
    address public immutable pool;
    address public owner;

    event LoanReceived(address token, uint256 amount, uint256 fee);
    event ArbitrageExecuted(uint256 profit);

    error Unauthorized();
    error InvalidCaller();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address _pool) {
        pool = _pool;
        owner = msg.sender;
    }

    function onFlashLoan(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override {
        if (msg.sender != pool) revert InvalidCaller();
        emit LoanReceived(token, amount, fee);
        uint256 repayAmount = amount + fee;
        IERC20(token).transfer(pool, repayAmount);
    }

    function initiateFlashLoan(uint256 amount, bytes calldata data) external onlyOwner {
        IFlashLoan(pool).flashLoan(amount, data);
    }

    function rescue(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
}
