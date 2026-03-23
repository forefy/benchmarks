// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpendingPolicy {
    function checkLimit(address user, uint256 amount) external view returns (bool);
}

interface IAssetRegistry {
    function isSupported(address asset) external view returns (bool);
}

contract TreasuryVault {
    address public owner;
    mapping(address => bool) public authorized;
    ISpendingPolicy public spendingPolicy;
    IAssetRegistry public assetRegistry;

    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event AuthorizationGranted(address indexed user);
    event AuthorizationRevoked(address indexed user);
    event Withdrawal(address indexed user, uint256 amount);
    event PolicySet(address indexed policy);
    event RegistrySet(address indexed registry);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;
    }

    function setOwner(address newOwner) external {
        owner = newOwner;
        authorized[newOwner] = true;
    }

    function grantAuthorization(address user) external onlyOwner {
        authorized[user] = true;
        emit AuthorizationGranted(user);
    }

    function revokeAuthorization(address user) external onlyOwner {
        authorized[user] = false;
        emit AuthorizationRevoked(user);
    }

    function setSpendingPolicy(address policy) external onlyOwner {
        spendingPolicy = ISpendingPolicy(policy);
        emit PolicySet(policy);
    }

    function setAssetRegistry(address registry) external onlyOwner {
        assetRegistry = IAssetRegistry(registry);
        emit RegistrySet(registry);
    }

    function withdraw(uint256 amount) external {
        require(authorized[msg.sender], "not authorized");
        require(address(this).balance >= amount, "insufficient");
        if (address(spendingPolicy) != address(0)) {
            require(spendingPolicy.checkLimit(msg.sender, amount), "limit exceeded");
        }
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "failed");
        emit Withdrawal(msg.sender, amount);
    }

    receive() external payable {}
}
