// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITreasury {
    event WithdrawalQueued(
        uint256 indexed index,
        address indexed to,
        uint256 amount,
        address token,
        uint256 readyAt
    );
    event WithdrawalExecuted(uint256 indexed index, address indexed to, uint256 amount, address token);
    event WithdrawalCancelled(uint256 indexed index);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    error NotOwner();
    error AlreadyExecuted();
    error NotReady(uint256 readyAt, uint256 current);
    error ExceedsLimit();
    error TransferFailed();

    function queueWithdrawal(address to, uint256 amount, address token, string calldata description) external;
    function executeWithdrawal(uint256 index) external;
    function cancelWithdrawal(uint256 index) external;
    function queueLength() external view returns (uint256);
    function pendingCount() external view returns (uint256);
    function ethBalance() external view returns (uint256);
    function tokenBalance(address token) external view returns (uint256);
}
