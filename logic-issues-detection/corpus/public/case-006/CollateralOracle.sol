// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CollateralOracle {
    address public owner;
    uint256 public price;
    uint256 public updatedAt;
    uint256 public constant STALENESS_THRESHOLD = 1 hours;

    event PriceUpdated(uint256 newPrice, uint256 timestamp);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    error Unauthorized();
    error StalePrice();
    error ZeroPrice();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(uint256 _initialPrice) {
        if (_initialPrice == 0) revert ZeroPrice();
        owner = msg.sender;
        price = _initialPrice;
        updatedAt = block.timestamp;
    }

    function setPrice(uint256 _price) external onlyOwner {
        if (_price == 0) revert ZeroPrice();
        price = _price;
        updatedAt = block.timestamp;
        emit PriceUpdated(_price, block.timestamp);
    }

    function getPrice() external view returns (uint256) {
        if (block.timestamp - updatedAt > STALENESS_THRESHOLD) revert StalePrice();
        return price;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
