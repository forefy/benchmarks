// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract TokenVesting {
    struct Grant {
        uint256 total;
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 claimed;
    }

    IERC20 public token;
    mapping(address => Grant) public grants;

    constructor(address _token) {
        token = _token;
    }

    function createGrant(
        address beneficiary,
        uint256 total,
        uint256 cliff,
        uint256 duration
    ) external {
        require(duration > cliff, 'duration must exceed cliff');
        grants[beneficiary] = Grant(total, block.timestamp, cliff, duration, 0);
    }

    function vested(address beneficiary) public view returns (uint256) {
        Grant memory g = grants[beneficiary];
        if (g.total == 0) return 0;
        if (block.timestamp < g.start + g.cliff) return 0;
        uint256 elapsed = block.timestamp - g.start;
        if (elapsed >= g.duration) return g.total;
        return g.total * elapsed / g.duration;
    }

    function claim() external {
        uint256 claimable = vested(msg.sender) - grants[msg.sender].claimed;
        require(claimable > 0, 'nothing to claim');
        grants[msg.sender].claimed += claimable;
        token.transfer(msg.sender, claimable);
    }
}
