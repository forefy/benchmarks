// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BondMarket {
    struct Market {
        address owner;
        uint256 price;
        uint256 discountBps;
        uint256 sold;
        uint256 capacity;
    }

    mapping(uint256 => Market) public markets;
    uint256 public nextId;

    function createMarket(
        uint256 price,
        uint256 discountBps,
        uint256 capacity
    ) external returns (uint256 id) {
        id = nextId++;
        markets[id] = Market(msg.sender, price, discountBps, 0, capacity);
    }

    function purchase(uint256 marketId, uint256 amount) external payable {
        Market storage m = markets[marketId];
        require(m.sold + amount <= m.capacity, 'sold out');
        uint256 effectivePrice = m.price * (10000 - m.discountBps) / 10000;
        require(msg.value >= effectivePrice * amount, 'insufficient payment');
        m.sold += amount;
    }
}