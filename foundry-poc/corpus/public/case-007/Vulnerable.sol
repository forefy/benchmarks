// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingRegistry {
    function isWhitelisted(address token) external view returns (bool);
}

interface IRewardToken {
    function mint(address to, uint256 amount) external;
}

contract StakingRewards {
    mapping(address => uint256) public staked;
    mapping(address => uint256) public pendingRewards;
    uint256 public totalStaked;
    uint256 public rewardPool;

    IStakingRegistry public registry;
    IRewardToken public rewardToken;
    address public governance;
    uint256 public epoch;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsFunded(uint256 amount);
    event GovernanceTransferred(address indexed previous, address indexed next);

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    constructor() {
        governance = msg.sender;
    }

    function setGovernance(address newGovernance) external onlyGovernance {
        emit GovernanceTransferred(governance, newGovernance);
        governance = newGovernance;
    }

    function setRegistry(address _registry) external onlyGovernance {
        registry = IStakingRegistry(_registry);
    }

    function setRewardToken(address _rewardToken) external onlyGovernance {
        rewardToken = IRewardToken(_rewardToken);
    }

    function incrementEpoch() external onlyGovernance {
        epoch += 1;
    }

    function stake(uint256 amount) external payable {
        require(msg.value == amount, "mismatch");
        if (totalStaked > 0) {
            pendingRewards[msg.sender] += (amount * rewardPool) / totalStaked;
        }
        staked[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function fundRewards() external payable {
        rewardPool += msg.value;
        emit RewardsFunded(msg.value);
    }

    function claimRewards() external {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "no rewards");
        (bool ok,) = msg.sender.call{value: reward}("");
        require(ok, "failed");
        pendingRewards[msg.sender] = 0;
        if (address(rewardToken) != address(0)) {
            rewardToken.mint(msg.sender, reward);
        }
        emit RewardsClaimed(msg.sender, reward);
    }

    function unstake() external {
        uint256 amount = staked[msg.sender];
        require(amount > 0, "not staked");
        staked[msg.sender] = 0;
        totalStaked -= amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "failed");
        emit Unstaked(msg.sender, amount);
    }
}
