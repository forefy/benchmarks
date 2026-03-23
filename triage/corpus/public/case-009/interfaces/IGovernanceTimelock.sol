// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernanceTimelock {
    event Queued(bytes32 indexed txHash, address target, uint256 value, bytes data, uint256 eta);
    event Executed(bytes32 indexed txHash, address target, uint256 value, bytes data);
    event Cancelled(bytes32 indexed txHash);
    event GovernanceUpdated(address indexed oldGov, address indexed newGov);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event MinDelayUpdated(uint256 oldDelay, uint256 newDelay);

    error NotGovernance();
    error NotGuardian();
    error AlreadyQueued(bytes32 txHash);
    error NotQueued(bytes32 txHash);
    error TooEarly(uint256 eta, uint256 current);
    error Expired(uint256 eta, uint256 current);
    error AlreadyExecuted(bytes32 txHash);
    error ExecutionFailed(bytes32 txHash);

    function queue(address target, uint256 value, bytes calldata data, uint256 delay) external returns (bytes32);
    function execute(bytes32 txHash, address target, uint256 value, bytes calldata data) external;
    function cancel(bytes32 txHash) external;
    function updateGovernance(address newGov) external;
    function updateGuardian(address newGuardian) external;
    function updateMinDelay(uint256 newDelay) external;
    function isQueued(bytes32 txHash) external view returns (bool);
}
