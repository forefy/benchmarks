// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISubscription {
    function subscribe(uint256 numWeeks) external;
    function cancel() external;
    function isSubscribed(address user) external view returns (bool);
    function expiryOf(address user) external view returns (uint256);
}
