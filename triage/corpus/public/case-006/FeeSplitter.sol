// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Simple fee splitter. Accumulated ETH is split between two beneficiaries.
contract FeeSplitter {
    address public partyA;
    address public partyB;
    uint256 public shareA;
    uint256 public shareB;

    constructor(address _partyA, address _partyB, uint256 _shareA, uint256 _shareB) {
        require(_shareA + _shareB == 100, "shares must sum to 100");
        partyA = _partyA;
        partyB = _partyB;
        shareA = _shareA;
        shareB = _shareB;
    }

    receive() external payable {}

    function split() external {
        uint256 balance = address(this).balance;
        uint256 amountA = (balance * shareA) / 100;
        uint256 amountB = balance - amountA;
        payable(partyA).transfer(amountA);
        payable(partyB).transfer(amountB);
    }
}
