// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingRewards {
    mapping(address => uint256) public staked;
    mapping(address => uint256) public rewardDebt;
    uint256 public accRewardPerShare;
    uint256 public totalStaked;

    function stake(uint256 amount) external {
        totalStaked += amount;
        staked[msg.sender] += amount;
    }

    function distributeRewards(uint256 rewardAmount) external {
        if (totalStaked > 0) {
            accRewardPerShare += rewardAmount * 1e12 / totalStaked;
        }
    }

    function harvest() external returns (uint256 reward) {
        reward = staked[msg.sender] * accRewardPerShare / 1e12 - rewardDebt[msg.sender];
        rewardDebt[msg.sender] = staked[msg.sender] * accRewardPerShare / 1e12;
    }

    function unstake(uint256 amount) external {
        require(staked[msg.sender] >= amount, 'insufficient');
        harvest();
        staked[msg.sender] -= amount;
        totalStaked -= amount;
    }
}