// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingRegistry {
    address public admin;
    mapping(address => bool) public whitelist;
    address[] public tokens;

    event TokenWhitelisted(address indexed token);
    event TokenRemoved(address indexed token);

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    function whitelistToken(address token) external onlyAdmin {
        whitelist[token] = true;
        tokens.push(token);
        emit TokenWhitelisted(token);
    }

    function removeToken(address token) external onlyAdmin {
        whitelist[token] = false;
        emit TokenRemoved(token);
    }

    function isWhitelisted(address token) external view returns (bool) {
        return whitelist[token];
    }

    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}
