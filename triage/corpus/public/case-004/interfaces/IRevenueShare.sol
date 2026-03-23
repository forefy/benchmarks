// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRevenueShare {
    event Locked(address indexed user, uint256 amount, uint256 epoch);
    event Unlocked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, address indexed rewardToken, uint256 amount);
    event RewardsDistributed(address indexed distributor, address indexed rewardToken, uint256 amount, uint256 epoch);
    event EpochAdvanced(uint256 indexed newEpoch, uint256 timestamp);
    event LockupPeriodUpdated(uint256 newPeriod);

    error InsufficientLocked();
    error LockupNotExpired(uint256 unlocksAt);
    error NoLockers();
    error ZeroAmount();

    function lock(uint256 amount) external;
    function unlock(uint256 amount) external;
    function claimRewards() external;
    function distributeRewards(uint256 amount) external;
    function pendingRewards(address user) external view returns (uint256);
    function currentEpoch() external view returns (uint256);
}
