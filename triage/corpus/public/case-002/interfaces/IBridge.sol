// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridge {
    event RootSynced(bytes32 indexed newRoot, uint256 indexed epoch);
    event Claimed(bytes32 indexed depositId, address indexed recipient, uint256 amount);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event FeeCollected(address indexed recipient, uint256 amount);

    error AlreadyClaimed(bytes32 depositId);
    error InvalidProof(bytes32 depositId);
    error ZeroAddress();
    error FeeTooHigh();

    function claim(
        address recipient,
        uint256 amount,
        bytes32 depositId,
        bytes32[] calldata proof
    ) external;

    function syncRoot(bytes32 newRoot) external;
    function merkleRoot() external view returns (bytes32);
    function currentEpoch() external view returns (uint256);
}
