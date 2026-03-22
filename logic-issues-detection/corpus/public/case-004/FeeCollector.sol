// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FeeCollector {
    address public treasury;
    uint256 public feeBps = 30;

    constructor(address _treasury) {
        treasury = _treasury;
    }

    function setFeeBps(uint256 newFee) external {
        require(newFee <= 1000, 'fee too high');
        feeBps = newFee;
    }

    function setTreasury(address newTreasury) external {
        treasury = newTreasury;
    }

    function collectFee(uint256 amount) external returns (uint256 fee) {
        fee = amount * feeBps / 10000;
    }
}