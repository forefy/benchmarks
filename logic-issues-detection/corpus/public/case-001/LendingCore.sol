// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IOracle.sol";

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract LendingCore {
    IERC20 public immutable collateralToken;
    IOracle public immutable oracle;

    address public owner;

    uint256 public constant COLLATERAL_FACTOR_BPS = 7500;
    uint256 public constant LIQUIDATION_BPS = 8500;
    uint256 public constant BASIS_POINTS = 10_000;

    mapping(address => uint256) public collateralBalances;
    mapping(address => uint256) public borrowedAmounts;

    bool private _locked;
    bool public paused;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed borrower, address indexed liquidator, uint256 collateralSeized);
    event PauseToggled(bool paused);

    error Unauthorized();
    error ContractPaused();
    error Reentrant();
    error Undercollateralized();
    error NotLiquidatable();
    error BadPrice();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(address _collateralToken, address _oracle) {
        collateralToken = IERC20(_collateralToken);
        oracle = IOracle(_oracle);
        owner = msg.sender;
    }

    function depositCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        collateralBalances[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        uint256 price = oracle.getPrice();
        if (price == 0) revert BadPrice();
        uint256 collateralValue = collateralBalances[msg.sender] * price / 1e18;
        uint256 maxBorrow = collateralValue * COLLATERAL_FACTOR_BPS / BASIS_POINTS;
        require(borrowedAmounts[msg.sender] + amount <= maxBorrow, "undercollateralized");
        borrowedAmounts[msg.sender] += amount;
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        uint256 owed = borrowedAmounts[msg.sender];
        uint256 repayAmount = amount > owed ? owed : amount;
        borrowedAmounts[msg.sender] -= repayAmount;
        emit Repaid(msg.sender, repayAmount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant whenNotPaused {
        uint256 price = oracle.getPrice();
        if (price == 0) revert BadPrice();
        uint256 newCollateral = collateralBalances[msg.sender] - amount;
        uint256 collateralValue = newCollateral * price / 1e18;
        uint256 maxBorrow = collateralValue * COLLATERAL_FACTOR_BPS / BASIS_POINTS;
        require(borrowedAmounts[msg.sender] <= maxBorrow, "would undercollateralize");
        collateralBalances[msg.sender] = newCollateral;
        if (!collateralToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function liquidate(address borrower) external nonReentrant whenNotPaused {
        uint256 price = oracle.getPrice();
        if (price == 0) revert BadPrice();
        uint256 collateralValue = collateralBalances[borrower] * price / 1e18;
        uint256 threshold = collateralValue * LIQUIDATION_BPS / BASIS_POINTS;
        if (borrowedAmounts[borrower] <= threshold) revert NotLiquidatable();
        uint256 seized = collateralBalances[borrower];
        collateralBalances[borrower] = 0;
        borrowedAmounts[borrower] = 0;
        if (!collateralToken.transfer(msg.sender, seized)) revert TransferFailed();
        emit Liquidated(borrower, msg.sender, seized);
    }

    function healthFactor(address user) external view returns (uint256) {
        if (borrowedAmounts[user] == 0) return type(uint256).max;
        uint256 price = oracle.getPrice();
        if (price == 0) return 0;
        uint256 collateralValue = collateralBalances[user] * price / 1e18;
        return collateralValue * COLLATERAL_FACTOR_BPS * 1e18 / (borrowedAmounts[user] * BASIS_POINTS);
    }

    function maxBorrowable(address user) external view returns (uint256) {
        uint256 price = oracle.getPrice();
        if (price == 0) return 0;
        uint256 collateralValue = collateralBalances[user] * price / 1e18;
        uint256 maxBorrow = collateralValue * COLLATERAL_FACTOR_BPS / BASIS_POINTS;
        if (borrowedAmounts[user] >= maxBorrow) return 0;
        return maxBorrow - borrowedAmounts[user];
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseToggled(_paused);
    }
}
