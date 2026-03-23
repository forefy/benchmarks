// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingRewards {
    mapping(address => uint256) public staked;
    mapping(address => uint256) public pendingRewards;
    uint256 public totalStaked;
    uint256 public rewardPool;

    function stake(uint256 amount) external payable {
        require(msg.value == amount, "mismatch");
        if (totalStaked > 0) {
            pendingRewards[msg.sender] += (amount * rewardPool) / totalStaked;
        }
        staked[msg.sender] += amount;
        totalStaked += amount;
    }

    function fundRewards() external payable {
        rewardPool += msg.value;
    }

    function claimRewards() external {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "no rewards");
        (bool ok,) = msg.sender.call{value: reward}("");
        require(ok, "failed");
        pendingRewards[msg.sender] = 0;
    }

    function unstake() external {
        uint256 amount = staked[msg.sender];
        require(amount > 0, "not staked");
        staked[msg.sender] = 0;
        totalStaked -= amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "failed");
    }
}
