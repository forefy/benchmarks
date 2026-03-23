// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPerp {
    struct Position {
        address trader;
        int256 size;
        uint256 entryPrice;
        uint256 expiry;
        bool settled;
    }

    event PositionOpened(
        uint256 indexed positionId,
        address indexed trader,
        int256 size,
        uint256 entryPrice,
        uint256 expiry
    );
    event PositionSettled(uint256 indexed positionId, address indexed trader, int256 pnl, uint256 exitPrice);
    event InsuranceDeposited(address indexed sender, uint256 amount);
    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event MarginWithdrawn(address indexed trader, uint256 amount);

    error AlreadySettled(uint256 positionId);
    error NotExpired(uint256 positionId);
    error NoMargin();
    error InsuranceDepleted(uint256 deficit);
    error InsufficientMargin(address trader, uint256 requested, int256 available);
    error NotKeeper();
    error NotOwner();

    function openPosition(int256 size, uint256 entryPrice, uint256 duration) external payable returns (uint256 id);
    function settle(uint256 positionId, uint256 exitPrice) external;
    function withdraw(uint256 amount) external;
    function depositInsurance() external payable;
}
