// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract LinearVesting {
    struct Grant {
        uint256 total;
        uint256 start;
        uint256 duration;
        uint256 claimed;
        bool terminated;
        uint256 terminatedVested;
    }

    IERC20 public token;
    address public admin;
    mapping(address => Grant) public grants;

    event GrantCreated(address indexed beneficiary, uint256 total, uint256 start, uint256 duration);
    event Claimed(address indexed beneficiary, uint256 amount);
    event Terminated(address indexed beneficiary, uint256 vestedAtTermination);

    constructor(address _token) {
        token = IERC20(_token);
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, 'not admin');
        _;
    }

    function createGrant(
        address beneficiary,
        uint256 total,
        uint256 start,
        uint256 duration
    ) external onlyAdmin {
        require(grants[beneficiary].total == 0, 'grant exists');
        require(duration > 0, 'zero duration');
        grants[beneficiary] = Grant(total, start, duration, 0, false, 0);
        emit GrantCreated(beneficiary, total, start, duration);
    }

    function vested(address beneficiary) public view returns (uint256) {
        Grant storage g = grants[beneficiary];
        if (g.total == 0) return 0;
        if (g.terminated) return g.terminatedVested;
        if (block.timestamp < g.start) return 0;
        uint256 elapsed = block.timestamp - g.start;
        if (elapsed >= g.duration) return g.total;
        return (g.total * elapsed) / g.duration;
    }

    function claimable(address beneficiary) public view returns (uint256) {
        return vested(beneficiary) - grants[beneficiary].claimed;
    }

    function claim() external {
        Grant storage g = grants[msg.sender];
        uint256 amount = vested(msg.sender) - g.claimed;
        require(amount > 0, 'nothing to claim');
        g.claimed += amount;
        token.transfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    function terminate(address beneficiary) external onlyAdmin {
        Grant storage g = grants[beneficiary];
        require(g.total > 0, 'no grant');
        require(!g.terminated, 'already terminated');
        uint256 vestedNow = vested(beneficiary);
        g.terminated = true;
        g.terminatedVested = vestedNow;
        emit Terminated(beneficiary, vestedNow);
    }
}
