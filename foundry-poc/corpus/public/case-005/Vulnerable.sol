// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface IRewardScheduler {
    function getRewardRate() external view returns (uint256);
}

contract StakingPool {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;

    IStakingToken public stakingToken;
    IRewardScheduler public rewardScheduler;
    address public governance;
    uint256 public minDeposit;

    event Deposited(address indexed user, uint256 value, uint256 sharesIssued);
    event Withdrawn(address indexed user, uint256 shareAmount, uint256 ethOut);
    event GovernanceChanged(address indexed previous, address indexed next);
    event SchedulerSet(address indexed scheduler);

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    constructor() {
        governance = msg.sender;
        minDeposit = 0;
    }

    function setGovernance(address newGovernance) external onlyGovernance {
        emit GovernanceChanged(governance, newGovernance);
        governance = newGovernance;
    }

    function setRewardScheduler(address scheduler) external onlyGovernance {
        rewardScheduler = IRewardScheduler(scheduler);
        emit SchedulerSet(scheduler);
    }

    function setStakingToken(address token) external onlyGovernance {
        stakingToken = IStakingToken(token);
    }

    function setMinDeposit(uint256 amount) external onlyGovernance {
        minDeposit = amount;
    }

    function deposit() external payable {
        uint256 newShares;
        if (totalShares == 0) {
            newShares = msg.value;
        } else {
            newShares = (msg.value * totalShares) / totalAssets;
        }
        shares[msg.sender] += newShares;
        totalShares += newShares;
        totalAssets += msg.value;
        if (address(stakingToken) != address(0)) {
            stakingToken.mint(msg.sender, newShares);
        }
        emit Deposited(msg.sender, msg.value, newShares);
    }

    function withdraw(uint256 shareAmount) external {
        require(shares[msg.sender] >= shareAmount, "insufficient shares");
        uint256 ethOut = (shareAmount * totalAssets) / totalShares;
        if (address(stakingToken) != address(0)) {
            stakingToken.burn(msg.sender, shareAmount);
        }
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalAssets -= ethOut;
        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok);
        emit Withdrawn(msg.sender, shareAmount, ethOut);
    }

    receive() external payable {}
}
