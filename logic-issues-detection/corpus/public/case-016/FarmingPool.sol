// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract FarmingPool {
    IERC20 public lpToken;
    IERC20 public rewardToken;

    uint256 public accRewardPerShare;
    uint256 public totalStaked;
    uint256 public rewardPerBlock;
    uint256 public lastRewardBlock;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public rewardDebt;

    constructor(address _lp, address _reward, uint256 _rewardPerBlock) {
        lpToken = IERC20(_lp);
        rewardToken = IERC20(_reward);
        rewardPerBlock = _rewardPerBlock;
        lastRewardBlock = block.number;
    }

    function _updatePool() internal {
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = blocks * rewardPerBlock;
        accRewardPerShare += (reward * 1e12) / totalStaked;
        lastRewardBlock = block.number;
    }

    function pendingReward(address user) external view returns (uint256) {
        uint256 acc = accRewardPerShare;
        if (totalStaked > 0 && block.number > lastRewardBlock) {
            uint256 blocks = block.number - lastRewardBlock;
            acc += (blocks * rewardPerBlock * 1e12) / totalStaked;
        }
        return (staked[user] * acc) / 1e12 - rewardDebt[user];
    }

    function stake(uint256 amount) external {
        _updatePool();
        if (staked[msg.sender] > 0) {
            uint256 pending = (staked[msg.sender] * accRewardPerShare) / 1e12 - rewardDebt[msg.sender];
            if (pending > 0) rewardToken.transfer(msg.sender, pending);
        }
        lpToken.transferFrom(msg.sender, address(this), amount);
        staked[msg.sender] += amount;
        totalStaked += amount;
        rewardDebt[msg.sender] = (staked[msg.sender] * accRewardPerShare) / 1e12;
    }

    function unstake(uint256 amount) external {
        require(staked[msg.sender] >= amount, 'insufficient');
        _updatePool();
        uint256 pending = (staked[msg.sender] * accRewardPerShare) / 1e12 - rewardDebt[msg.sender];
        if (pending > 0) rewardToken.transfer(msg.sender, pending);
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        rewardDebt[msg.sender] = (staked[msg.sender] * accRewardPerShare) / 1e12;
        lpToken.transfer(msg.sender, amount);
    }

    function harvest() external {
        _updatePool();
        uint256 pending = (staked[msg.sender] * accRewardPerShare) / 1e12 - rewardDebt[msg.sender];
        require(pending > 0, 'nothing to harvest');
        rewardDebt[msg.sender] = (staked[msg.sender] * accRewardPerShare) / 1e12;
        rewardToken.transfer(msg.sender, pending);
    }
}
