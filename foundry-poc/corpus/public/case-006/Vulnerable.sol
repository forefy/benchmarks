// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProxyAdmin {
    function isUpgrader(address account) external view returns (bool);
    function recordUpgrade(address proxy, address newImpl) external;
}

contract UpgradeableVault {
    address public implementation;
    address public admin;

    IProxyAdmin public proxyAdmin;
    bytes32 public constant VERSION = keccak256("VaultImpl.v1");

    event Upgraded(address indexed newImpl);
    event AdminSet(address indexed admin);

    constructor(address _impl) {
        admin = msg.sender;
        implementation = _impl;
    }

    function upgrade(address newImpl) external {
        require(msg.sender == admin, "not admin");
        implementation = newImpl;
        emit Upgraded(newImpl);
    }

    function setAdmin(address newAdmin) external {
        require(msg.sender == admin, "not admin");
        admin = newAdmin;
        emit AdminSet(newAdmin);
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

    string public constant NAME = "YieldVault";
    uint256 public version;

    event Initialized(address indexed owner);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    function initialize(address _owner) external {
        owner = _owner;
        initialized = true;
        emit Initialized(_owner);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "not owner");
        require(address(this).balance >= amount, "insufficient");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "failed");
        emit Withdrawn(msg.sender, amount);
    }
}
