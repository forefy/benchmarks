// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IFlashLoan.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract CapitalPool is IFlashLoan {
    IERC20 public immutable token;
    address public owner;

    uint256 public constant FEE_BPS = 30;
    uint256 public constant BASIS_POINTS = 10_000;

    uint256 public maxLoanAmount;
    uint256 public totalFeesCollected;
    uint256 public totalLoansIssued;

    mapping(address => bool) public whitelisted;
    bool public whitelistEnabled;
    bool private _locked;

    event FlashLoanExecuted(address indexed borrower, uint256 amount, uint256 fee);
    event Deposited(address indexed depositor, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount);
    event WhitelistUpdated(address indexed account, bool status);
    event MaxLoanUpdated(uint256 newMax);

    error Unauthorized();
    error Reentrant();
    error NotWhitelisted();
    error ExceedsMaxLoan();
    error InsufficientLiquidity();
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

    constructor(address _token, uint256 _maxLoanAmount) {
        token = IERC20(_token);
        owner = msg.sender;
        maxLoanAmount = _maxLoanAmount;
    }

    function deposit(uint256 amount) external nonReentrant {
        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        if (!token.transfer(owner, amount)) revert TransferFailed();
        emit Withdrawn(owner, amount);
    }

    function maxFlashLoan() external view override returns (uint256) {
        uint256 balance = token.balanceOf(address(this));
        return balance < maxLoanAmount ? balance : maxLoanAmount;
    }

    function flashFee(uint256 amount) external pure override returns (uint256) {
        return amount * FEE_BPS / BASIS_POINTS;
    }

    function flashLoan(uint256 amount, bytes calldata data) external override nonReentrant {
        if (whitelistEnabled && !whitelisted[msg.sender]) revert NotWhitelisted();
        if (amount > maxLoanAmount) revert ExceedsMaxLoan();
        uint256 balanceBefore = token.balanceOf(address(this));
        if (amount > balanceBefore) revert InsufficientLiquidity();
        uint256 fee = amount * FEE_BPS / BASIS_POINTS;

        token.transfer(msg.sender, amount);
        IFlashBorrower(msg.sender).onFlashLoan(address(token), amount, fee, data);

        require(
            token.balanceOf(address(this)) >= balanceBefore - amount + fee,
            "repayment insufficient"
        );

        totalFeesCollected += fee;
        totalLoansIssued += amount;
        emit FlashLoanExecuted(msg.sender, amount, fee);
    }

    function setWhitelist(address account, bool status) external onlyOwner {
        whitelisted[account] = status;
        emit WhitelistUpdated(account, status);
    }

    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
    }

    function setMaxLoan(uint256 _maxLoanAmount) external onlyOwner {
        maxLoanAmount = _maxLoanAmount;
        emit MaxLoanUpdated(_maxLoanAmount);
    }

    function loanStats() external view returns (uint256 totalFees, uint256 totalLoans, uint256 availableLiquidity) {
        totalFees = totalFeesCollected;
        totalLoans = totalLoansIssued;
        availableLiquidity = token.balanceOf(address(this));
    }
}
