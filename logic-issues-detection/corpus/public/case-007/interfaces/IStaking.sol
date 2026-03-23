// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function harvest() external returns (uint256 reward);
    function pendingReward(address user) external view returns (uint256);
    function emergencyWithdraw() external;
}
