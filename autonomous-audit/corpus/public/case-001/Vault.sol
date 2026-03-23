// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract BatchTransfer {
    IERC20 public token;
    address public owner;
    mapping(address => bool) public operators;

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function addOperator(address op) external onlyOwner {
        operators[op] = true;
    }

    function removeOperator(address op) external onlyOwner {
        operators[op] = false;
    }

    function batchSend(address[] calldata recipients, uint256[] calldata amounts) external {
        require(operators[tx.origin], "not operator");
        require(recipients.length == amounts.length, "length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            token.transfer(recipients[i], amounts[i]);
        }
    }

    function deposit(uint256 amount) external onlyOwner {
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external onlyOwner {
        token.transfer(owner, amount);
    }
}
