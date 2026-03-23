// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UpgradeableVault {
    address public implementation;
    address public admin;

    constructor(address _impl) {
        admin = msg.sender;
        implementation = _impl;
    }

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

contract VaultImpl {
    address public owner;
    bool public initialized;
    mapping(address => uint256) public balances;

    function initialize(address _owner) external {
        owner = _owner;
        initialized = true;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "not owner");
        require(address(this).balance >= amount, "insufficient");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "failed");
    }
}
