// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVestingFactory {
    function createSchedule(
        address beneficiary,
        uint256 total,
        uint256 start,
        uint256 cliff,
        uint256 duration
    ) external returns (uint256 scheduleId);

    function claim(uint256 scheduleId) external;
    function vested(uint256 scheduleId) external view returns (uint256);
    function terminate(uint256 scheduleId) external;
}
