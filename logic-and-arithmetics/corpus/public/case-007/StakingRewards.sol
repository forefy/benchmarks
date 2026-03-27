// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IStaking.sol";

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract StakingRewards is IStaking {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    address public owner;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public rewardDebt;
    uint256 public accRewardPerShare;
    uint256 public totalStaked;

    uint256 public rewardRate;
    uint256 public lastRewardBlock;
    uint256 public rewardEndBlock;

    bool private _locked;
    bool public paused;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Harvested(address indexed user, uint256 reward);
    event RewardsDistributed(uint256 amount);
    event EmergencyWithdrawn(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate, uint256 endBlock);
    event PauseToggled(bool paused);

    error Unauthorized();
    error ContractPaused();
    error Reentrant();
    error InsufficientStake();
    error ZeroAmount();
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

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        owner = msg.sender;
        lastRewardBlock = block.number;
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) return;
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 endBlock = block.number < rewardEndBlock ? block.number : rewardEndBlock;
        if (endBlock > lastRewardBlock) {
            uint256 blocks = endBlock - lastRewardBlock;
            uint256 reward = blocks * rewardRate;
            accRewardPerShare += reward * 1e12 / totalStaked;
        }
        lastRewardBlock = block.number;
    }

    function stake(uint256 amount) external override nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        _updatePool();
        if (!stakingToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        totalStaked += amount;
        staked[msg.sender] += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external override nonReentrant whenNotPaused {
        if (staked[msg.sender] < amount) revert InsufficientStake();
        _updatePool();
        _harvest(msg.sender);
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        if (!stakingToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit Unstaked(msg.sender, amount);
    }

    function harvest() external override nonReentrant whenNotPaused returns (uint256 reward) {
        _updatePool();
        reward = _harvest(msg.sender);
    }

    function _harvest(address user) internal returns (uint256 reward) {
        reward = staked[user] * accRewardPerShare / 1e12 - rewardDebt[user];
        rewardDebt[user] = staked[user] * accRewardPerShare / 1e12;
        if (reward > 0) {
            if (!rewardToken.transfer(user, reward)) revert TransferFailed();
            emit Harvested(user, reward);
        }
    }

    function distributeRewards(uint256 rewardAmount) external {
        if (totalStaked > 0) {
            accRewardPerShare += rewardAmount * 1e12 / totalStaked;
        }
        emit RewardsDistributed(rewardAmount);
    }

    function emergencyWithdraw() external override nonReentrant {
        uint256 amount = staked[msg.sender];
        if (amount == 0) revert ZeroAmount();
        staked[msg.sender] = 0;
        rewardDebt[msg.sender] = 0;
        totalStaked -= amount;
        if (!stakingToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit EmergencyWithdrawn(msg.sender, amount);
    }

    function pendingReward(address user) external view override returns (uint256) {
        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 endBlock = block.number < rewardEndBlock ? block.number : rewardEndBlock;
            if (endBlock > lastRewardBlock) {
                uint256 blocks = endBlock - lastRewardBlock;
                uint256 reward = blocks * rewardRate;
                _accRewardPerShare += reward * 1e12 / totalStaked;
            }
        }
        return staked[user] * _accRewardPerShare / 1e12 - rewardDebt[user];
    }

    function setRewardRate(uint256 _rewardRate, uint256 _rewardEndBlock) external onlyOwner {
        _updatePool();
        rewardRate = _rewardRate;
        rewardEndBlock = _rewardEndBlock;
        emit RewardRateUpdated(_rewardRate, _rewardEndBlock);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseToggled(_paused);
    }
}
