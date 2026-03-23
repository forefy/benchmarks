// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Perpetual futures settlement. A keeper calls settle() for expired positions.
// PnL is credited or debited from trader margin accounts.
// Insurance fund covers losses when a trader's margin goes negative.
contract PerpSettlement {
    address public owner;
    address public keeper;

    mapping(address => int256) public margin;
    mapping(uint256 => Position) public positions;
    uint256 public insuranceFund;
    uint256 public nextPositionId;

    struct Position {
        address trader;
        int256 size;
        uint256 entryPrice;
        uint256 expiry;
        bool settled;
    }

    constructor(address _keeper) {
        owner = msg.sender;
        keeper = _keeper;
    }

    modifier onlyKeeper() {
        require(msg.sender == keeper, "not keeper");
        _;
    }

    function openPosition(int256 size, uint256 entryPrice, uint256 duration) external payable returns (uint256 id) {
        require(msg.value > 0, "no margin");
        id = nextPositionId++;
        positions[id] = Position(msg.sender, size, entryPrice, block.timestamp + duration, false);
        margin[msg.sender] += int256(msg.value);
    }

    function depositInsurance() external payable {
        insuranceFund += msg.value;
    }

    function settle(uint256 positionId, uint256 exitPrice) external onlyKeeper {
        Position storage pos = positions[positionId];
        require(!pos.settled, "settled");
        require(block.timestamp >= pos.expiry, "not expired");
        pos.settled = true;

        int256 pnl = pos.size > 0
            ? int256(exitPrice - pos.entryPrice) * pos.size
            : int256(pos.entryPrice - exitPrice) * (-pos.size);

        margin[pos.trader] += pnl;

        if (margin[pos.trader] < 0) {
            uint256 deficit = uint256(-margin[pos.trader]);
            require(insuranceFund >= deficit, "insurance depleted");
            insuranceFund -= deficit;
            margin[pos.trader] = 0;
        }
    }

    function withdraw(uint256 amount) external {
        require(margin[msg.sender] >= int256(amount), "insufficient margin");
        margin[msg.sender] -= int256(amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "failed");
    }

    function setKeeper(address newKeeper) external {
        require(msg.sender == owner, "not owner");
        keeper = newKeeper;
    }

    receive() external payable {}
}
