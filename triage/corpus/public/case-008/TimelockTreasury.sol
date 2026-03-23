// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Time-locked treasury. Funds can only be withdrawn after a 48h delay.
// Multisig owners queue withdrawals; any owner can execute after delay.
contract TimelockTreasury {
    address[] public owners;
    mapping(address => bool) public isOwner;

    struct Withdrawal {
        address to;
        uint256 amount;
        uint256 readyAt;
        bool executed;
    }

    Withdrawal[] public queue;

    constructor(address[] memory _owners) {
        for (uint256 i = 0; i < _owners.length; i++) {
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
    }

    receive() external payable {}

    function queueWithdrawal(address to, uint256 amount) external {
        require(isOwner[msg.sender], "not owner");
        queue.push(Withdrawal({ to: to, amount: amount, readyAt: block.timestamp + 48 hours, executed: false }));
    }

    function executeWithdrawal(uint256 index) external {
        require(isOwner[msg.sender], "not owner");
        Withdrawal storage w = queue[index];
        require(!w.executed, "already executed");
        require(block.timestamp >= w.readyAt, "not ready");
        w.executed = true;
        payable(w.to).transfer(w.amount);
    }

    function cancelWithdrawal(uint256 index) external {
        require(isOwner[msg.sender], "not owner");
        queue[index].executed = true;
    }
}
