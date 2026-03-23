// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TreasuryVault {
    address public owner;
    mapping(address => bool) public authorized;

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;
    }

    function setOwner(address newOwner) external {
        owner = newOwner;
        authorized[newOwner] = true;
    }

    function withdraw(uint256 amount) external {
        require(authorized[msg.sender], "not authorized");
        require(address(this).balance >= amount, "insufficient");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "failed");
    }

    receive() external payable {}
}
