// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ProxyAdmin {
    address public owner;
    mapping(address => bool) public upgraders;
    address[] public upgradeHistory;

    event UpgraderAdded(address indexed upgrader);
    event UpgraderRemoved(address indexed upgrader);
    event OwnerChanged(address indexed previous, address indexed next);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyUpgrader() {
        require(upgraders[msg.sender], "not upgrader");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function addUpgrader(address account) external onlyOwner {
        upgraders[account] = true;
        emit UpgraderAdded(account);
    }

    function removeUpgrader(address account) external onlyOwner {
        upgraders[account] = false;
        emit UpgraderRemoved(account);
    }

    function isUpgrader(address account) external view returns (bool) {
        return upgraders[account];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    function recordUpgrade(address proxy, address newImpl) external onlyUpgrader {
        upgradeHistory.push(newImpl);
    }

    function upgradeCount() external view returns (uint256) {
        return upgradeHistory.length;
    }
}
