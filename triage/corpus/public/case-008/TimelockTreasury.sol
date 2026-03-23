// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITreasury.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TimelockTreasury is ITreasury {
    address[] public owners;
    mapping(address => bool) public isOwner;

    uint256 public constant TIMELOCK_DELAY = 48 hours;
    uint256 public constant MAX_SINGLE_WITHDRAWAL = 100 ether;

    struct Withdrawal {
        address to;
        uint256 amount;
        address token;
        uint256 readyAt;
        bool executed;
        bool cancelled;
        string description;
    }

    Withdrawal[] public queue;

    mapping(address => uint256) public spentToday;
    mapping(address => uint256) public spendingLimitPerDay;
    mapping(address => uint256) public lastSpendReset;

    event WithdrawalQueued(uint256 indexed index, address indexed to, uint256 amount, address token, uint256 readyAt);
    event WithdrawalExecuted(uint256 indexed index, address indexed to, uint256 amount, address token);
    event WithdrawalCancelled(uint256 indexed index);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event SpendingLimitSet(address indexed token, uint256 limit);

    error NotOwner();
    error AlreadyExecuted();
    error NotReady(uint256 readyAt, uint256 current);
    error ExceedsLimit();
    error TransferFailed();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    constructor(address[] memory _owners) {
        require(_owners.length > 0, "no owners");
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "zero owner");
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
            emit OwnerAdded(_owners[i]);
        }
    }

    receive() external payable {}

    function queueWithdrawal(address to, uint256 amount, address token, string calldata description) external onlyOwner {
        require(amount <= MAX_SINGLE_WITHDRAWAL, "exceeds max");
        uint256 readyAt = block.timestamp + TIMELOCK_DELAY;
        queue.push(Withdrawal({
            to: to,
            amount: amount,
            token: token,
            readyAt: readyAt,
            executed: false,
            cancelled: false,
            description: description
        }));
        emit WithdrawalQueued(queue.length - 1, to, amount, token, readyAt);
    }

    function executeWithdrawal(uint256 index) external onlyOwner {
        Withdrawal storage w = queue[index];
        if (w.executed || w.cancelled) revert AlreadyExecuted();
        if (block.timestamp < w.readyAt) revert NotReady(w.readyAt, block.timestamp);
        w.executed = true;
        if (w.token == address(0)) {
            (bool ok,) = w.to.call{value: w.amount}("");
            if (!ok) revert TransferFailed();
        } else {
            bool ok = IERC20(w.token).transfer(w.to, w.amount);
            if (!ok) revert TransferFailed();
        }
        emit WithdrawalExecuted(index, w.to, w.amount, w.token);
    }

    function cancelWithdrawal(uint256 index) external onlyOwner {
        Withdrawal storage w = queue[index];
        require(!w.executed, "already executed");
        w.cancelled = true;
        emit WithdrawalCancelled(index);
    }

    function queueLength() external view returns (uint256) {
        return queue.length;
    }

    function pendingCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < queue.length; i++) {
            if (!queue[i].executed && !queue[i].cancelled) count++;
        }
    }

    function ethBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function tokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function ownerCount() external view returns (uint256) {
        return owners.length;
    }

    function isExecutable(uint256 index) external view returns (bool) {
        if (index >= queue.length) return false;
        Withdrawal storage w = queue[index];
        return !w.executed && !w.cancelled && block.timestamp >= w.readyAt;
    }
}
