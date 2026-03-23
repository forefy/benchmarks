// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Dollar-cost averaging helper. Users deposit ETH and the contract
// auto-buys a target token on a configurable schedule via a DEX.
contract DCAVault {
    address public owner;
    address public dex;
    address public targetToken;

    mapping(address => uint256) public ethBalance;
    mapping(address => uint256) public nextBuyTime;
    mapping(address => uint256) public interval;
    mapping(address => uint256) public amountPerBuy;

    constructor(address _dex, address _targetToken) {
        owner = msg.sender;
        dex = _dex;
        targetToken = _targetToken;
    }

    receive() external payable {
        ethBalance[msg.sender] += msg.value;
    }

    function configure(uint256 _interval, uint256 _amountPerBuy) external {
        require(_interval >= 1 hours, "interval too short");
        require(_amountPerBuy > 0, "zero amount");
        interval[msg.sender] = _interval;
        amountPerBuy[msg.sender] = _amountPerBuy;
        nextBuyTime[msg.sender] = block.timestamp;
    }

    function executeBuy(address user) external {
        require(block.timestamp >= nextBuyTime[user], "not ready");
        require(ethBalance[user] >= amountPerBuy[user], "insufficient balance");
        nextBuyTime[user] = block.timestamp + interval[user];
        ethBalance[user] -= amountPerBuy[user];

        (bool ok,) = dex.call{value: amountPerBuy[user]}(
            abi.encodeWithSignature("buyToken(address,address)", targetToken, user)
        );
        require(ok, "buy failed");
    }

    function withdraw() external {
        uint256 amount = ethBalance[msg.sender];
        ethBalance[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}
