// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ILendingMarket.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IOracleAdapter {
    function getPrice(address token) external view returns (uint256);
}

contract LendingMarket is ILendingMarket {
    IERC20 public collateral;
    IERC20 public debt;
    IOracleAdapter public oracle;

    mapping(address => uint256) public deposited;
    mapping(address => uint256) public borrowed;

    uint256 public constant LTV = 75;
    uint256 public constant LIQUIDATION_BONUS = 105;
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant PRECISION = 100;

    address public immutable owner;

    uint256 private _totalDeposited;
    uint256 private _totalBorrowed;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonZero(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    constructor(address _collateral, address _debt, address _oracle) {
        collateral = IERC20(_collateral);
        debt = IERC20(_debt);
        oracle = IOracleAdapter(_oracle);
        owner = msg.sender;
    }

    function deposit(uint256 amount) external nonZero(amount) {
        collateral.transferFrom(msg.sender, address(this), amount);
        deposited[msg.sender] += amount;
        _totalDeposited += amount;
        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonZero(amount) {
        uint256 max = maxBorrow(msg.sender);
        if (borrowed[msg.sender] + amount > max) revert ExceedsMaxBorrow();
        borrowed[msg.sender] += amount;
        _totalBorrowed += amount;
        debt.transfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonZero(amount) {
        debt.transferFrom(msg.sender, address(this), amount);
        borrowed[msg.sender] -= amount;
        _totalBorrowed -= amount;
        emit Repaid(msg.sender, amount);
    }

    function forceClose(address user, uint256 repayAmount) external {
        require(borrowed[user] > 0, "no debt");
        debt.transferFrom(msg.sender, address(this), repayAmount);
        borrowed[user] -= repayAmount;
        uint256 collateralSeized = (repayAmount * LIQUIDATION_BONUS) / 100;
        deposited[user] -= collateralSeized;
        collateral.transfer(msg.sender, collateralSeized);
        emit ForceClosed(user, msg.sender, repayAmount, collateralSeized);
    }

    function healthFactor(address user) external view returns (uint256) {
        if (borrowed[user] == 0) return type(uint256).max;
        return (deposited[user] * LIQUIDATION_THRESHOLD * 1e18) / (borrowed[user] * PRECISION);
    }

    function maxBorrow(address user) public view returns (uint256) {
        return (deposited[user] * LTV) / PRECISION;
    }

    function currentUtilization() external view returns (uint256) {
        if (_totalDeposited == 0) return 0;
        return (_totalBorrowed * 10000) / _totalDeposited;
    }

    function totalDeposited() external view returns (uint256) {
        return _totalDeposited;
    }

    function totalBorrowed() external view returns (uint256) {
        return _totalBorrowed;
    }

    function setOracle(address newOracle) external onlyOwner {
        oracle = IOracleAdapter(newOracle);
        emit OracleUpdated(newOracle);
    }
}
