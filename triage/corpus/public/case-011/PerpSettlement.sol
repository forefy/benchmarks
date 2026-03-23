// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IPerp.sol";

interface IFundingCalculator {
    function recordOpen(uint256 positionId) external;
    function applyFunding(uint256 positionId, int256 size) external view returns (int256);
    function pendingFunding(uint256 positionId, int256 size) external view returns (int256);
}

contract PerpSettlement is IPerp {
    address public owner;
    address public keeper;

    mapping(address => int256) public margin;
    mapping(uint256 => Position) public positions;
    uint256 public insuranceFund;
    uint256 public nextPositionId;

    IFundingCalculator public fundingCalculator;

    uint256 public totalSettled;
    uint256 public totalInsuranceUsed;

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert NotKeeper();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _keeper, address _fundingCalculator) {
        owner = msg.sender;
        keeper = _keeper;
        fundingCalculator = IFundingCalculator(_fundingCalculator);
    }

    function openPosition(int256 size, uint256 entryPrice, uint256 duration) external payable returns (uint256 id) {
        if (msg.value == 0) revert NoMargin();
        id = nextPositionId++;
        positions[id] = Position({
            trader: msg.sender,
            size: size,
            entryPrice: entryPrice,
            expiry: block.timestamp + duration,
            settled: false
        });
        margin[msg.sender] += int256(msg.value);
        if (address(fundingCalculator) != address(0)) {
            fundingCalculator.recordOpen(id);
        }
        emit PositionOpened(id, msg.sender, size, entryPrice, block.timestamp + duration);
    }

    function depositInsurance() external payable {
        insuranceFund += msg.value;
        emit InsuranceDeposited(msg.sender, msg.value);
    }

    function settle(uint256 positionId, uint256 exitPrice) external onlyKeeper {
        Position storage pos = positions[positionId];
        if (pos.settled) revert AlreadySettled(positionId);
        if (block.timestamp < pos.expiry) revert NotExpired(positionId);
        pos.settled = true;
        totalSettled += 1;

        int256 pnl = pos.size > 0
            ? int256(exitPrice - pos.entryPrice) * pos.size
            : int256(pos.entryPrice - exitPrice) * (-pos.size);

        margin[pos.trader] += pnl;

        if (margin[pos.trader] < 0) {
            uint256 deficit = uint256(-margin[pos.trader]);
            if (insuranceFund < deficit) revert InsuranceDepleted(deficit);
            insuranceFund -= deficit;
            totalInsuranceUsed += deficit;
            margin[pos.trader] = 0;
        }

        emit PositionSettled(positionId, pos.trader, pnl, exitPrice);
    }

    function withdraw(uint256 amount) external {
        if (margin[msg.sender] < int256(amount)) {
            revert InsufficientMargin(msg.sender, amount, margin[msg.sender]);
        }
        margin[msg.sender] -= int256(amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");
        emit MarginWithdrawn(msg.sender, amount);
    }

    function setKeeper(address newKeeper) external onlyOwner {
        emit KeeperUpdated(keeper, newKeeper);
        keeper = newKeeper;
    }

    function setFundingCalculator(address calc) external onlyOwner {
        fundingCalculator = IFundingCalculator(calc);
    }

    function positionPnl(uint256 positionId, uint256 currentPrice) external view returns (int256) {
        Position storage pos = positions[positionId];
        if (pos.settled) return 0;
        return pos.size > 0
            ? int256(currentPrice - pos.entryPrice) * pos.size
            : int256(pos.entryPrice - currentPrice) * (-pos.size);
    }

    receive() external payable {}
}
