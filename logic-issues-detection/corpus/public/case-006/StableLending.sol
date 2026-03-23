// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StableLending {
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    uint256 public constant COLLATERAL_FACTOR = 150;
    address public owner;

    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, 'reentrant');
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'unauthorized');
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function depositCollateral() external payable nonReentrant {
        collateral[msg.sender] += msg.value;
    }

    function borrow(uint256 amount) external nonReentrant {
        uint256 maxBorrow = collateral[msg.sender] * 100 / COLLATERAL_FACTOR;
        require(debt[msg.sender] + amount <= maxBorrow, 'undercollateralized');
        debt[msg.sender] += amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, 'transfer failed');
    }

    function repay() external payable nonReentrant {
        require(debt[msg.sender] >= msg.value, 'overpay');
        debt[msg.sender] -= msg.value;
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        uint256 remaining = collateral[msg.sender] - amount;
        uint256 maxBorrow = remaining * 100 / COLLATERAL_FACTOR;
        require(debt[msg.sender] <= maxBorrow, 'would undercollateralize');
        collateral[msg.sender] = remaining;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, 'transfer failed');
    }

    receive() external payable {}
}
