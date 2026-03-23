// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRevenueShare.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract RevenueShare is IRevenueShare {
    IERC20 public token;
    IERC20 public rewardToken;

    mapping(address => uint256) public locked;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public lockTimestamp;

    uint256 public totalLocked;
    uint256 public accRewardPerShare;
    uint256 public epoch;

    uint256 public lockupPeriod;
    uint256 public constant MIN_LOCKUP = 1 days;
    uint256 public constant MAX_LOCKUP = 365 days;

    uint256 public totalRewardsDistributed;
    uint256 public totalRewardsClaimed;

    address public immutable admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor(address _token, address _rewardToken, uint256 _lockupPeriod) {
        require(_lockupPeriod >= MIN_LOCKUP && _lockupPeriod <= MAX_LOCKUP, "invalid lockup");
        token = IERC20(_token);
        rewardToken = IERC20(_rewardToken);
        lockupPeriod = _lockupPeriod;
        admin = msg.sender;
    }

    function lock(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _claimRewards();
        token.transferFrom(msg.sender, address(this), amount);
        locked[msg.sender] += amount;
        totalLocked += amount;
        lockTimestamp[msg.sender] = block.timestamp;
        rewardDebt[msg.sender] = (locked[msg.sender] * accRewardPerShare) / 1e12;
        emit Locked(msg.sender, amount, epoch);
    }

    function unlock(uint256 amount) external {
        if (locked[msg.sender] < amount) revert InsufficientLocked();
        uint256 unlocksAt = lockTimestamp[msg.sender] + lockupPeriod;
        if (block.timestamp < unlocksAt) revert LockupNotExpired(unlocksAt);
        _claimRewards();
        locked[msg.sender] -= amount;
        totalLocked -= amount;
        rewardDebt[msg.sender] = (locked[msg.sender] * accRewardPerShare) / 1e12;
        token.transfer(msg.sender, amount);
        emit Unlocked(msg.sender, amount);
    }

    function claimRewards() external {
        _claimRewards();
    }

    function _claimRewards() internal {
        if (locked[msg.sender] == 0) return;
        uint256 pending = (locked[msg.sender] * accRewardPerShare) / 1e12 - rewardDebt[msg.sender];
        if (pending > 0) {
            totalRewardsClaimed += pending;
            rewardDebt[msg.sender] = (locked[msg.sender] * accRewardPerShare) / 1e12;
            rewardToken.transfer(msg.sender, pending);
            emit RewardsClaimed(msg.sender, address(rewardToken), pending);
        }
    }

    function distributeRewards(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (totalLocked == 0) revert NoLockers();
        rewardToken.transferFrom(msg.sender, address(this), amount);
        accRewardPerShare += (amount * 1e12) / totalLocked;
        totalRewardsDistributed += amount;
        emit RewardsDistributed(msg.sender, address(rewardToken), amount, epoch);
        epoch += 1;
        emit EpochAdvanced(epoch, block.timestamp);
    }

    function pendingRewards(address user) external view returns (uint256) {
        if (locked[user] == 0) return 0;
        return (locked[user] * accRewardPerShare) / 1e12 - rewardDebt[user];
    }

    function currentEpoch() external view returns (uint256) {
        return epoch;
    }

    function setLockupPeriod(uint256 newPeriod) external onlyAdmin {
        require(newPeriod >= MIN_LOCKUP && newPeriod <= MAX_LOCKUP, "invalid lockup");
        lockupPeriod = newPeriod;
        emit LockupPeriodUpdated(newPeriod);
    }

    function rewardRate() external view returns (uint256) {
        if (totalLocked == 0) return 0;
        return (accRewardPerShare * totalLocked) / 1e12;
    }

    function userInfo(address user) external view returns (
        uint256 lockedAmount,
        uint256 pending,
        uint256 unlocksAt,
        uint256 debt
    ) {
        lockedAmount = locked[user];
        pending = lockedAmount == 0 ? 0 : (lockedAmount * accRewardPerShare) / 1e12 - rewardDebt[user];
        unlocksAt = lockTimestamp[user] + lockupPeriod;
        debt = rewardDebt[user];
    }

    function globalStats() external view returns (
        uint256 _totalLocked,
        uint256 _totalRewardsDistributed,
        uint256 _totalRewardsClaimed,
        uint256 _epoch
    ) {
        _totalLocked = totalLocked;
        _totalRewardsDistributed = totalRewardsDistributed;
        _totalRewardsClaimed = totalRewardsClaimed;
        _epoch = epoch;
    }
}
