// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StakingPool {
    IERC20 public token;
    address public owner;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public lastUpdateBlock;

    uint256 public rewardPerBlock = 1e18;
    uint256 public totalStaked;

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    function stake(uint256 amount) external {
        _updateRewards(msg.sender);
        token.transferFrom(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
    }

    function _updateRewards(address user) internal {
        if (lastUpdateBlock[user] == 0) {
            lastUpdateBlock[user] = block.number;
            return;
        }
        uint256 blocks = block.number - lastUpdateBlock[user];
        uint256 userShare = (stakedBalance[user] * 1e18) / totalStaked;
        uint256 reward = (blocks * rewardPerBlock * userShare) / 1e18;
        pendingRewards[user] += reward;
        lastUpdateBlock[user] = block.number;
    }

    function claimRewards() external {
        _updateRewards(msg.sender);
        uint256 reward = pendingRewards[msg.sender];
        pendingRewards[msg.sender] = 0;
        token.transfer(msg.sender, reward);
    }

    function unstake(uint256 amount) external {
        require(stakedBalance[msg.sender] >= amount, "insufficient stake");
        _updateRewards(msg.sender);
        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        token.transfer(msg.sender, amount);
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external {
        rewardPerBlock = _rewardPerBlock;
    }
}
