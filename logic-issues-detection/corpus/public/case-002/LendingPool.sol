// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ILendingPool.sol";

contract LendingPool is ILendingPool {
    uint256 public totalBorrows;
    uint256 public borrowIndex = 1e18;
    uint256 public totalDeposits;
    uint256 public lastAccrualBlock;

    address public owner;
    bool private _locked;
    bool public paused;

    uint256 public constant INTEREST_RATE_PER_BLOCK = 1e12;

    mapping(address => uint256) public borrowShares;
    mapping(address => uint256) public depositBalances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount, uint256 shares);
    event Repaid(address indexed borrower, uint256 amount, uint256 shares);
    event IndexAccrued(uint256 newIndex, uint256 blockNumber);
    event PauseToggled(bool paused);

    error Unauthorized();
    error ContractPaused();
    error Reentrant();
    error InsufficientDeposit();
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

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor() {
        owner = msg.sender;
        lastAccrualBlock = block.number;
    }

    function accrueInterest() public {
        uint256 blockDelta = block.number - lastAccrualBlock;
        if (blockDelta == 0) return;
        if (totalBorrows > 0) {
            uint256 interestFactor = blockDelta * INTEREST_RATE_PER_BLOCK;
            borrowIndex = borrowIndex + borrowIndex * interestFactor / 1e18;
            totalBorrows = totalBorrows + totalBorrows * interestFactor / 1e18;
        }
        lastAccrualBlock = block.number;
        emit IndexAccrued(borrowIndex, block.number);
    }

    function deposit() external payable override nonReentrant whenNotPaused {
        accrueInterest();
        depositBalances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override nonReentrant whenNotPaused {
        accrueInterest();
        if (depositBalances[msg.sender] < amount) revert InsufficientDeposit();
        if (address(this).balance < amount) revert InsufficientLiquidity();
        depositBalances[msg.sender] -= amount;
        totalDeposits -= amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external override nonReentrant whenNotPaused {
        accrueInterest();
        if (address(this).balance < amount) revert InsufficientLiquidity();
        uint256 shares = amount / borrowIndex;
        borrowShares[msg.sender] += shares;
        totalBorrows += amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Borrowed(msg.sender, amount, shares);
    }

    function repay(address borrower) external payable override nonReentrant {
        accrueInterest();
        uint256 owed = borrowShares[borrower] * borrowIndex;
        require(msg.value >= owed, "insufficient");
        uint256 shares = borrowShares[borrower];
        delete borrowShares[borrower];
        totalBorrows -= owed;
        emit Repaid(borrower, owed, shares);
        if (msg.value > owed) {
            (bool ok,) = msg.sender.call{value: msg.value - owed}("");
            if (!ok) revert TransferFailed();
        }
    }

    function getBorrowBalance(address borrower) external view override returns (uint256) {
        return borrowShares[borrower] * borrowIndex / 1e18;
    }

    function utilizationRate() external view override returns (uint256) {
        if (totalDeposits == 0) return 0;
        return totalBorrows * 1e18 / totalDeposits;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseToggled(_paused);
    }

    receive() external payable {}
}
