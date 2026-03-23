// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RewardToken {
    string public constant name = "Protocol Reward Token";
    string public constant symbol = "PRT";
    uint8 public constant decimals = 18;

    address public distributor;
    uint256 public constant MAX_SUPPLY = 100_000_000 ether;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    modifier onlyDistributor() {
        require(msg.sender == distributor, "not distributor");
        _;
    }

    constructor(address _distributor) {
        distributor = _distributor;
    }

    function mint(address to, uint256 amount) external onlyDistributor {
        require(totalSupply + amount <= MAX_SUPPLY, "max supply exceeded");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "insufficient balance");
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
