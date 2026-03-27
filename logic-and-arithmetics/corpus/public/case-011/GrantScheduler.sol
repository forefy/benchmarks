// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GrantScheduler {
    address public admin;

    struct ScheduledGrant {
        address beneficiary;
        uint256 total;
        uint256 cliff;
        uint256 duration;
        bool executed;
    }

    ScheduledGrant[] public scheduledGrants;

    event GrantScheduled(uint256 indexed index, address indexed beneficiary, uint256 total);
    event GrantExecuted(uint256 indexed index, address indexed beneficiary);

    error Unauthorized();
    error AlreadyExecuted();
    error InvalidIndex();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function scheduleGrant(
        address beneficiary,
        uint256 total,
        uint256 cliff,
        uint256 duration
    ) external onlyAdmin returns (uint256 index) {
        index = scheduledGrants.length;
        scheduledGrants.push(ScheduledGrant(beneficiary, total, cliff, duration, false));
        emit GrantScheduled(index, beneficiary, total);
    }

    function markExecuted(uint256 index) external onlyAdmin {
        if (index >= scheduledGrants.length) revert InvalidIndex();
        if (scheduledGrants[index].executed) revert AlreadyExecuted();
        scheduledGrants[index].executed = true;
        emit GrantExecuted(index, scheduledGrants[index].beneficiary);
    }

    function getPendingGrants() external view returns (uint256[] memory indices) {
        uint256 count;
        for (uint256 i = 0; i < scheduledGrants.length; i++) {
            if (!scheduledGrants[i].executed) count++;
        }
        indices = new uint256[](count);
        uint256 j;
        for (uint256 i = 0; i < scheduledGrants.length; i++) {
            if (!scheduledGrants[i].executed) indices[j++] = i;
        }
    }

    function totalScheduled() external view returns (uint256) {
        return scheduledGrants.length;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}
