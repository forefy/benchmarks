// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IStableLending.sol";

contract StableLending is IStableLending {
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    uint256 public constant COLLATERAL_FACTOR = 150;
    address public owner;
    uint256 public debtCeiling;
    uint256 public totalDebt;

    bool private _locked;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 collateralSeized, uint256 debtCleared);
    event DebtCeilingUpdated(uint256 newCeiling);

    error Unauthorized();
    error Reentrant();
    error Undercollateralized();
    error DebtCeilingExceeded();
    error Overpayment();
    error WouldUndercollateralize();
    error NotLiquidatable();
    error TransferFailed();

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(uint256 _debtCeiling) {
        owner = msg.sender;
        debtCeiling = _debtCeiling;
    }

    function depositCollateral() external payable override nonReentrant {
        collateral[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    function borrow(uint256 amount) external override nonReentrant {
        uint256 maxBorrow = collateral[msg.sender] * 100 / COLLATERAL_FACTOR;
        if (debt[msg.sender] + amount > maxBorrow) revert Undercollateralized();
        if (totalDebt + amount > debtCeiling) revert DebtCeilingExceeded();
        debt[msg.sender] += amount;
        totalDebt += amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Borrowed(msg.sender, amount);
    }

    function repay() external payable override nonReentrant {
        if (debt[msg.sender] < msg.value) revert Overpayment();
        debt[msg.sender] -= msg.value;
        totalDebt -= msg.value;
        emit Repaid(msg.sender, msg.value);
    }

    function withdrawCollateral(uint256 amount) external override nonReentrant {
        uint256 remaining = collateral[msg.sender] - amount;
        uint256 maxBorrow = remaining * 100 / COLLATERAL_FACTOR;
        if (debt[msg.sender] > maxBorrow) revert WouldUndercollateralize();
        collateral[msg.sender] = remaining;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function liquidate(address user) external nonReentrant {
        uint256 maxBorrow = collateral[user] * 100 / COLLATERAL_FACTOR;
        if (debt[user] <= maxBorrow) revert NotLiquidatable();
        uint256 seized = collateral[user];
        uint256 cleared = debt[user];
        collateral[user] = 0;
        debt[user] = 0;
        totalDebt -= cleared;
        (bool ok,) = msg.sender.call{value: seized}("");
        if (!ok) revert TransferFailed();
        emit Liquidated(user, msg.sender, seized, cleared);
    }

    function healthFactor(address user) external view override returns (uint256) {
        if (debt[user] == 0) return type(uint256).max;
        return collateral[user] * 100 * 1e18 / (debt[user] * COLLATERAL_FACTOR);
    }

    function maxBorrowable(address user) external view returns (uint256) {
        uint256 maxBorrow = collateral[user] * 100 / COLLATERAL_FACTOR;
        if (debt[user] >= maxBorrow) return 0;
        return maxBorrow - debt[user];
    }

    function setDebtCeiling(uint256 newCeiling) external onlyOwner {
        debtCeiling = newCeiling;
        emit DebtCeilingUpdated(newCeiling);
    }

    receive() external payable {}
}
