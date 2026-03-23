// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SpendingPolicy {
    address public treasury;
    mapping(address => uint256) public dailyLimit;
    mapping(address => uint256) public spent;
    mapping(address => uint256) public lastReset;

    event LimitSet(address indexed user, uint256 limit);
    event SpendRecorded(address indexed user, uint256 amount);

    modifier onlyTreasury() {
        require(msg.sender == treasury, "not treasury");
        _;
    }

    constructor(address _treasury) {
        treasury = _treasury;
    }

    function setLimit(address user, uint256 limit) external onlyTreasury {
        dailyLimit[user] = limit;
        emit LimitSet(user, limit);
    }

    function checkLimit(address user, uint256 amount) external view returns (bool) {
        uint256 currentSpent = spent[user];
        if (block.timestamp > lastReset[user] + 1 days) {
            currentSpent = 0;
        }
        return currentSpent + amount <= dailyLimit[user];
    }

    function recordSpend(address user, uint256 amount) external onlyTreasury {
        if (block.timestamp > lastReset[user] + 1 days) {
            spent[user] = 0;
            lastReset[user] = block.timestamp;
        }
        spent[user] += amount;
        emit SpendRecorded(user, amount);
    }
}
