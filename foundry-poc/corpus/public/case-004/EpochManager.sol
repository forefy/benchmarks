// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EpochManager {
    address public governance;
    uint256 public epochDuration;
    uint256 public genesisTime;
    mapping(uint256 => uint256) public epochRewardRate;

    event EpochRateSet(uint256 indexed epoch, uint256 rate);
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    constructor(uint256 _epochDuration) {
        governance = msg.sender;
        epochDuration = _epochDuration;
        genesisTime = block.timestamp;
    }

    function currentEpoch() external view returns (uint256) {
        return (block.timestamp - genesisTime) / epochDuration;
    }

    function setEpochRate(uint256 epoch, uint256 rate) external onlyGovernance {
        epochRewardRate[epoch] = rate;
        emit EpochRateSet(epoch, rate);
    }

    function transferGovernance(address newGovernance) external onlyGovernance {
        emit GovernanceTransferred(governance, newGovernance);
        governance = newGovernance;
    }
}
