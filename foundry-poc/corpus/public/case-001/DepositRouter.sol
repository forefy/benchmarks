// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balances(address user) external view returns (uint256);
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DepositRouter {
    ITokenVault public vault;
    IERC20 public token;
    uint256 public minDeposit;
    address public governance;

    event DepositRouted(address indexed user, uint256 amount);
    event WithdrawRouted(address indexed user, uint256 amount);

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    constructor(address _vault, address _token, uint256 _minDeposit) {
        vault = ITokenVault(_vault);
        token = IERC20(_token);
        minDeposit = _minDeposit;
        governance = msg.sender;
    }

    function depositWithSlippage(uint256 amount, uint256 minAccepted) external {
        require(amount >= minDeposit, "below min deposit");
        uint256 balanceBefore = vault.balances(address(this));
        token.transferFrom(msg.sender, address(this), amount);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        uint256 balanceAfter = vault.balances(address(this));
        require(balanceAfter - balanceBefore >= minAccepted, "slippage exceeded");
        emit DepositRouted(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        vault.withdraw(amount);
        emit WithdrawRouted(msg.sender, amount);
    }

    function setMinDeposit(uint256 _minDeposit) external onlyGovernance {
        minDeposit = _minDeposit;
    }

    function setGovernance(address newGovernance) external onlyGovernance {
        governance = newGovernance;
    }
}
