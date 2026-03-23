// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowVault {
    mapping(address => uint256) public deposits;
    mapping(address => address payable) public recipients;
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, 'reentrant');
        _locked = true;
        _;
        _locked = false;
    }

    function deposit(address payable recipient) external payable nonReentrant {
        deposits[msg.sender] += msg.value;
        recipients[msg.sender] = recipient;
    }

    function withdrawTo(address payable to) external {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, 'empty');
        (bool ok,) = to.call{value: amount}("");
        require(ok, 'failed');
        deposits[msg.sender] = 0;
    }

    function cancel() external nonReentrant {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, 'empty');
        deposits[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, 'failed');
    }
}
