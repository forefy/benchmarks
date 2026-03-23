// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IToken {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Vault {
    mapping(address => uint256) public balances;
    IToken public token;

    constructor(address _token) { token = _token; }

    function deposit(uint256 amount) external {
        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, 'insufficient');
        token.transfer(msg.sender, amount);
        balances[msg.sender] -= amount;
    }
}