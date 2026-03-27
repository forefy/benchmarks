// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVesting.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract VestingVault is IVesting {
    struct Grant {
        uint256 total;
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 claimed;
        bool revoked;
        uint256 revokedVested;
    }

    IERC20 public immutable token;
    address public admin;

    mapping(address => Grant) public grants;

    event GrantCreated(address indexed beneficiary, uint256 total, uint256 cliff, uint256 duration);
    event Claimed(address indexed beneficiary, uint256 amount);
    event GrantRevoked(address indexed beneficiary, uint256 vestedAtRevocation, uint256 returned);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);
    event Accelerated(address indexed beneficiary, uint256 newDuration);

    error Unauthorized();
    error GrantExists();
    error NoGrant();
    error AlreadyRevoked();
    error NothingToClaim();
    error InvalidParams();
    error TransferFailed();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        admin = msg.sender;
    }

    function createGrant(
        address beneficiary,
        uint256 total,
        uint256 cliff,
        uint256 duration
    ) external override onlyAdmin {
        if (grants[beneficiary].total != 0) revert GrantExists();
        if (duration <= cliff) revert InvalidParams();
        if (total == 0) revert InvalidParams();
        if (!token.transferFrom(msg.sender, address(this), total)) revert TransferFailed();
        grants[beneficiary] = Grant(total, block.timestamp, cliff, duration, 0, false, 0);
        emit GrantCreated(beneficiary, total, cliff, duration);
    }

    function vested(address beneficiary) public view override returns (uint256) {
        Grant memory g = grants[beneficiary];
        if (g.total == 0) return 0;
        if (g.revoked) return g.revokedVested;
        if (block.timestamp < g.start + g.cliff) return 0;
        uint256 elapsed = block.timestamp - g.start;
        if (elapsed >= g.duration) return g.total;
        return g.total * elapsed / g.duration;
    }

    function claim() external override {
        Grant storage g = grants[msg.sender];
        if (g.total == 0) revert NoGrant();
        uint256 claimable = vested(msg.sender) - g.claimed;
        if (claimable == 0) revert NothingToClaim();
        g.claimed += claimable;
        if (!token.transfer(msg.sender, claimable)) revert TransferFailed();
        emit Claimed(msg.sender, claimable);
    }

    function revokeGrant(address beneficiary) external override onlyAdmin {
        Grant storage g = grants[beneficiary];
        if (g.total == 0) revert NoGrant();
        if (g.revoked) revert AlreadyRevoked();
        uint256 vestedNow = vested(beneficiary);
        uint256 returned = g.total - vestedNow;
        g.revoked = true;
        g.revokedVested = vestedNow;
        if (returned > 0) {
            if (!token.transfer(admin, returned)) revert TransferFailed();
        }
        emit GrantRevoked(beneficiary, vestedNow, returned);
    }

    function accelerate(address beneficiary, uint256 newDuration) external onlyAdmin {
        Grant storage g = grants[beneficiary];
        if (g.total == 0) revert NoGrant();
        if (g.revoked) revert AlreadyRevoked();
        require(newDuration < g.duration, "must shorten duration");
        g.duration = newDuration;
        emit Accelerated(beneficiary, newDuration);
    }

    function claimable(address beneficiary) external view returns (uint256) {
        return vested(beneficiary) - grants[beneficiary].claimed;
    }

    function grantInfo(address beneficiary) external view returns (
        uint256 total,
        uint256 vestedAmount,
        uint256 claimed,
        uint256 claimableAmount,
        bool revoked
    ) {
        Grant storage g = grants[beneficiary];
        total = g.total;
        vestedAmount = vested(beneficiary);
        claimed = g.claimed;
        claimableAmount = vestedAmount - g.claimed;
        revoked = g.revoked;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        emit AdminTransferred(admin, newAdmin);
        admin = newAdmin;
    }
}
