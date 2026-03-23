// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IERC20Receiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external;
}

interface IVaultToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract TokenVault {
    IERC20 public token;
    IVaultToken public vaultToken;
    address public manager;
    uint256 public depositCap;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event ManagerUpdated(address indexed previousManager, address indexed newManager);
    event VaultTokenSet(address indexed vaultToken);

    modifier onlyManager() {
        require(msg.sender == manager, "not manager");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        manager = msg.sender;
        depositCap = type(uint256).max;
    }

    function setManager(address newManager) external onlyManager {
        emit ManagerUpdated(manager, newManager);
        manager = newManager;
    }

    function setVaultToken(address _vaultToken) external onlyManager {
        vaultToken = IVaultToken(_vaultToken);
        emit VaultTokenSet(_vaultToken);
    }

    function setDepositCap(uint256 cap) external onlyManager {
        depositCap = cap;
    }

    function deposit(uint256 amount) external {
        require(token.balanceOf(address(this)) + amount <= depositCap, "cap exceeded");
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
        if (address(vaultToken) != address(0)) {
            vaultToken.mint(msg.sender, amount);
        }
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient");
        token.transfer(msg.sender, amount);
        if (msg.sender.code.length > 0) {
            IERC20Receiver(msg.sender).tokensReceived(address(token), amount, "");
        }
        balances[msg.sender] -= amount;
        if (address(vaultToken) != address(0)) {
            vaultToken.burn(msg.sender, amount);
        }
        emit Withdrawal(msg.sender, amount);
    }

    function totalDeposited() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
