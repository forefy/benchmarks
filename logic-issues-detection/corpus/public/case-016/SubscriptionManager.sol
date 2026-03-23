// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SubscriptionManager {
    IERC20 public paymentToken;
    address public owner;
    uint256 public weeklyRate;

    struct Subscription {
        uint256 expiry;
    }

    mapping(address => Subscription) public subscriptions;

    constructor(address _token, uint256 _weeklyRate) {
        paymentToken = IERC20(_token);
        owner = msg.sender;
        weeklyRate = _weeklyRate;
    }

    function subscribe(uint256 numWeeks) external {
        require(numWeeks > 0, "zero weeks");
        uint256 cost = weeklyRate * numWeeks;
        paymentToken.transferFrom(msg.sender, address(this), cost);
        uint256 start = subscriptions[msg.sender].expiry > block.timestamp
            ? subscriptions[msg.sender].expiry
            : block.timestamp;
        subscriptions[msg.sender].expiry = start + (1 weeks * numWeeks);
    }

    function cancel() external {
        uint256 expiry = subscriptions[msg.sender].expiry;
        require(expiry > block.timestamp, "no active subscription");
        uint256 remaining = expiry - block.timestamp;
        uint256 refund = (remaining * weeklyRate) / 1 weeks;
        subscriptions[msg.sender].expiry = block.timestamp;
        paymentToken.transfer(msg.sender, refund);
    }

    function setRate(uint256 newRate) external {
        require(msg.sender == owner, "not owner");
        weeklyRate = newRate;
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "not owner");
        paymentToken.transfer(owner, amount);
    }
}
