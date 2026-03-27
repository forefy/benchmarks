// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVestingFactory.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract VestingFactory is IVestingFactory {
    struct Schedule {
        address beneficiary;
        address token;
        uint256 total;
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 claimed;
        bool terminated;
        uint256 terminatedVested;
    }

    address public admin;
    uint256 public scheduleCount;

    mapping(uint256 => Schedule) public schedules;
    mapping(address => uint256[]) public beneficiarySchedules;

    event ScheduleCreated(uint256 indexed scheduleId, address indexed beneficiary, address token, uint256 total, uint256 start, uint256 cliff, uint256 duration);
    event Claimed(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event Terminated(uint256 indexed scheduleId, address indexed beneficiary, uint256 vestedAtTermination, uint256 returned);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);

    error Unauthorized();
    error ZeroTotal();
    error ZeroDuration();
    error CliffExceedsDuration();
    error ScheduleTerminated();
    error NothingToClaim();
    error NotBeneficiary();
    error InvalidSchedule();
    error TransferFailed();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function createSchedule(
        address beneficiary,
        uint256 total,
        uint256 start,
        uint256 cliff,
        uint256 duration
    ) external override onlyAdmin returns (uint256 scheduleId) {
        return _createSchedule(beneficiary, address(0), total, start, cliff, duration);
    }

    function createScheduleForToken(
        address beneficiary,
        address token,
        uint256 total,
        uint256 start,
        uint256 cliff,
        uint256 duration
    ) external onlyAdmin returns (uint256 scheduleId) {
        return _createSchedule(beneficiary, token, total, start, cliff, duration);
    }

    function _createSchedule(
        address beneficiary,
        address token,
        uint256 total,
        uint256 start,
        uint256 cliff,
        uint256 duration
    ) internal returns (uint256 scheduleId) {
        if (total == 0) revert ZeroTotal();
        if (duration == 0) revert ZeroDuration();
        if (cliff > duration) revert CliffExceedsDuration();
        if (token != address(0)) {
            if (!IERC20(token).transferFrom(msg.sender, address(this), total)) revert TransferFailed();
        }
        scheduleId = scheduleCount++;
        schedules[scheduleId] = Schedule({
            beneficiary: beneficiary,
            token: token,
            total: total,
            start: start,
            cliff: cliff,
            duration: duration,
            claimed: 0,
            terminated: false,
            terminatedVested: 0
        });
        beneficiarySchedules[beneficiary].push(scheduleId);
        emit ScheduleCreated(scheduleId, beneficiary, token, total, start, cliff, duration);
    }

    function vested(uint256 scheduleId) public view override returns (uint256) {
        Schedule storage s = schedules[scheduleId];
        if (s.total == 0) revert InvalidSchedule();
        if (s.terminated) return s.terminatedVested;
        if (block.timestamp < s.start + s.cliff) return 0;
        uint256 elapsed = block.timestamp - s.start;
        if (elapsed >= s.duration) return s.total;
        return s.total * elapsed / s.duration;
    }

    function claimable(uint256 scheduleId) public view returns (uint256) {
        return vested(scheduleId) - schedules[scheduleId].claimed;
    }

    function claim(uint256 scheduleId) external override {
        Schedule storage s = schedules[scheduleId];
        if (s.total == 0) revert InvalidSchedule();
        if (msg.sender != s.beneficiary) revert NotBeneficiary();
        uint256 amount = vested(scheduleId) - s.claimed;
        if (amount == 0) revert NothingToClaim();
        s.claimed += amount;
        if (s.token != address(0)) {
            if (!IERC20(s.token).transfer(s.beneficiary, amount)) revert TransferFailed();
        }
        emit Claimed(scheduleId, s.beneficiary, amount);
    }

    function terminate(uint256 scheduleId) external override onlyAdmin {
        Schedule storage s = schedules[scheduleId];
        if (s.total == 0) revert InvalidSchedule();
        if (s.terminated) revert ScheduleTerminated();
        uint256 vestedNow = vested(scheduleId);
        uint256 returned = s.total - vestedNow;
        s.terminated = true;
        s.terminatedVested = vestedNow;
        if (returned > 0 && s.token != address(0)) {
            if (!IERC20(s.token).transfer(admin, returned)) revert TransferFailed();
        }
        emit Terminated(scheduleId, s.beneficiary, vestedNow, returned);
    }

    function getBeneficiarySchedules(address beneficiary) external view returns (uint256[] memory) {
        return beneficiarySchedules[beneficiary];
    }

    function totalClaimable(address beneficiary) external view returns (uint256 total) {
        uint256[] storage ids = beneficiarySchedules[beneficiary];
        for (uint256 i = 0; i < ids.length; i++) {
            if (!schedules[ids[i]].terminated) {
                total += claimable(ids[i]);
            }
        }
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        emit AdminTransferred(admin, newAdmin);
        admin = newAdmin;
    }
}
