// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RewardScheduler {
    address public governance;
    uint256 public baseRate;
    uint256 public startTime;
    uint256 public endTime;
    bool public active;

    event ScheduleConfigured(uint256 start, uint256 end, uint256 rate);
    event RateUpdated(uint256 rate);

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    constructor(address _governance) {
        governance = _governance;
    }

    function configureSchedule(uint256 start, uint256 end, uint256 rate) external onlyGovernance {
        startTime = start;
        endTime = end;
        baseRate = rate;
        emit ScheduleConfigured(start, end, rate);
    }

    function getRewardRate() external view returns (uint256) {
        if (active && block.timestamp >= startTime && block.timestamp <= endTime) {
            return baseRate;
        }
        return 0;
    }

    function setRate(uint256 rate) external onlyGovernance {
        baseRate = rate;
        emit RateUpdated(rate);
    }

    function activate() external onlyGovernance {
        active = true;
    }

    function deactivate() external onlyGovernance {
        active = false;
    }
}
