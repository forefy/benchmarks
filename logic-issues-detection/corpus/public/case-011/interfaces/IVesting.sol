// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVesting {
    function createGrant(address beneficiary, uint256 total, uint256 cliff, uint256 duration) external;
    function vested(address beneficiary) external view returns (uint256);
    function claim() external;
    function revokeGrant(address beneficiary) external;
}
