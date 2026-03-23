// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// LP reward distributor. Tracks each user's LP token balance and distributes
// reward tokens proportionally over a fixed emission period.
contract LPRewardDistributor {
    IERC20 public lpToken;
    IERC20 public rewardToken;
    address public owner;

    uint256 public emissionRate;
    uint256 public periodEnd;
    uint256 public lastUpdated;
    uint256 public accRewardPerLP;
    uint256 public totalDeposited;

    mapping(address => uint256) public balance;
    mapping(address => uint256) public rewardDebt;

    constructor(address _lp, address _reward) {
        lpToken = IERC20(_lp);
        rewardToken = IERC20(_reward);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function startEmission(uint256 totalReward, uint256 duration) external onlyOwner {
        require(block.timestamp >= periodEnd, "period active");
        rewardToken.transferFrom(msg.sender, address(this), totalReward);
        emissionRate = totalReward / duration;
        periodEnd = block.timestamp + duration;
        lastUpdated = block.timestamp;
    }

    function _updatePool() internal {
        if (totalDeposited == 0 || block.timestamp <= lastUpdated) return;
        uint256 elapsed = min(block.timestamp, periodEnd) - lastUpdated;
        accRewardPerLP += (elapsed * emissionRate * 1e12) / totalDeposited;
        lastUpdated = block.timestamp;
    }

    function deposit(uint256 amount) external {
        _updatePool();
        if (balance[msg.sender] > 0) {
            uint256 pending = (balance[msg.sender] * accRewardPerLP) / 1e12 - rewardDebt[msg.sender];
            rewardToken.transfer(msg.sender, pending);
        }
        lpToken.transferFrom(msg.sender, address(this), amount);
        balance[msg.sender] += amount;
        totalDeposited += amount;
        rewardDebt[msg.sender] = (balance[msg.sender] * accRewardPerLP) / 1e12;
    }

    function withdraw(uint256 amount) external {
        require(balance[msg.sender] >= amount, "insufficient");
        _updatePool();
        uint256 pending = (balance[msg.sender] * accRewardPerLP) / 1e12 - rewardDebt[msg.sender];
        balance[msg.sender] -= amount;
        totalDeposited -= amount;
        rewardDebt[msg.sender] = (balance[msg.sender] * accRewardPerLP) / 1e12;
        if (pending > 0) rewardToken.transfer(msg.sender, pending);
        lpToken.transfer(msg.sender, amount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
