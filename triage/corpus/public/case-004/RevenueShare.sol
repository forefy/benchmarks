// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Revenue sharing contract. Protocol fees accumulate here and are distributed
// pro-rata to token holders who lock their tokens.
contract RevenueShare {
    IERC20 public token;
    IERC20 public rewardToken;

    mapping(address => uint256) public locked;
    mapping(address => uint256) public rewardDebt;
    uint256 public totalLocked;
    uint256 public accRewardPerShare;

    constructor(address _token, address _rewardToken) {
        token = IERC20(_token);
        rewardToken = IERC20(_rewardToken);
    }

    function lock(uint256 amount) external {
        _harvest();
        token.transferFrom(msg.sender, address(this), amount);
        locked[msg.sender] += amount;
        totalLocked += amount;
        rewardDebt[msg.sender] = (locked[msg.sender] * accRewardPerShare) / 1e12;
    }

    function unlock(uint256 amount) external {
        require(locked[msg.sender] >= amount, "insufficient");
        _harvest();
        locked[msg.sender] -= amount;
        totalLocked -= amount;
        rewardDebt[msg.sender] = (locked[msg.sender] * accRewardPerShare) / 1e12;
        token.transfer(msg.sender, amount);
    }

    function _harvest() internal {
        if (locked[msg.sender] == 0) return;
        uint256 pending = (locked[msg.sender] * accRewardPerShare) / 1e12 - rewardDebt[msg.sender];
        if (pending > 0) rewardToken.transfer(msg.sender, pending);
    }

    function distributeRewards(uint256 amount) external {
        require(totalLocked > 0, "no lockers");
        rewardToken.transferFrom(msg.sender, address(this), amount);
        accRewardPerShare += (amount * 1e12) / totalLocked;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
