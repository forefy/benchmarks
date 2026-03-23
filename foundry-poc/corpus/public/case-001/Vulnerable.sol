// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC20Receiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external;
}

contract TokenVault {
    IERC20 public token;
    mapping(address => uint256) public balances;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient");
        token.transfer(msg.sender, amount);
        if (msg.sender.code.length > 0) {
            IERC20Receiver(msg.sender).tokensReceived(address(token), amount, "");
        }
        balances[msg.sender] -= amount;
    }

    function totalDeposited() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
