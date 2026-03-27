// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVault.sol";

contract VaultRegistry {
    address public owner;

    struct VaultEntry {
        address vault;
        address asset;
        string name;
        bool active;
    }

    VaultEntry[] public vaults;
    mapping(address => uint256) public vaultIndex;
    mapping(address => bool) public isRegistered;

    event VaultRegistered(address indexed vault, address indexed asset, string name);
    event VaultDeactivated(address indexed vault);

    error Unauthorized();
    error AlreadyRegistered();
    error NotRegistered();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerVault(address vault, address asset, string calldata name) external onlyOwner {
        if (isRegistered[vault]) revert AlreadyRegistered();
        vaultIndex[vault] = vaults.length;
        vaults.push(VaultEntry(vault, asset, name, true));
        isRegistered[vault] = true;
        emit VaultRegistered(vault, asset, name);
    }

    function deactivateVault(address vault) external onlyOwner {
        if (!isRegistered[vault]) revert NotRegistered();
        vaults[vaultIndex[vault]].active = false;
        emit VaultDeactivated(vault);
    }

    function getActiveVaults() external view returns (VaultEntry[] memory active) {
        uint256 count;
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i].active) count++;
        }
        active = new VaultEntry[](count);
        uint256 j;
        for (uint256 i = 0; i < vaults.length; i++) {
            if (vaults[i].active) active[j++] = vaults[i];
        }
    }

    function totalVaults() external view returns (uint256) {
        return vaults.length;
    }
}
