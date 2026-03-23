// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IDCA.sol";

interface IPriceRouter {
    function validateSlippage(address token, uint256 amountOut, uint256 ethIn, uint256 maxSlippageBps) external view;
    function getExpectedOut(address token, uint256 ethIn) external view returns (uint256);
}

contract DCAVault is IDCA {
    address public owner;
    address public dex;
    address public targetToken;
    IPriceRouter public priceRouter;

    mapping(address => uint256) public ethBalance;
    mapping(address => uint256) public nextBuyTime;
    mapping(address => uint256) public interval;
    mapping(address => uint256) public amountPerBuy;
    mapping(address => uint256) public maxSlippageBps;
    mapping(address => uint256) public totalSpent;
    mapping(address => uint256) public totalBuys;

    address public keeper;

    uint256 public constant MIN_INTERVAL = 1 hours;
    uint256 public constant DEFAULT_SLIPPAGE_BPS = 200;

    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _dex, address _targetToken, address _priceRouter) {
        owner = msg.sender;
        dex = _dex;
        targetToken = _targetToken;
        priceRouter = IPriceRouter(_priceRouter);
    }

    receive() external payable {
        ethBalance[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function configure(uint256 _interval, uint256 _amountPerBuy) external {
        require(_interval >= MIN_INTERVAL, "interval too short");
        require(_amountPerBuy > 0, "zero amount");
        interval[msg.sender] = _interval;
        amountPerBuy[msg.sender] = _amountPerBuy;
        nextBuyTime[msg.sender] = block.timestamp;
        maxSlippageBps[msg.sender] = DEFAULT_SLIPPAGE_BPS;
        emit Configured(msg.sender, _interval, _amountPerBuy);
    }

    function configureWithSlippage(uint256 _interval, uint256 _amountPerBuy, uint256 _maxSlippageBps) external {
        require(_interval >= MIN_INTERVAL, "interval too short");
        require(_amountPerBuy > 0, "zero amount");
        require(_maxSlippageBps <= 1000, "slippage too high");
        interval[msg.sender] = _interval;
        amountPerBuy[msg.sender] = _amountPerBuy;
        maxSlippageBps[msg.sender] = _maxSlippageBps;
        nextBuyTime[msg.sender] = block.timestamp;
        emit Configured(msg.sender, _interval, _amountPerBuy);
    }

    function executeBuy(address user) external {
        require(block.timestamp >= nextBuyTime[user], "not ready");
        require(ethBalance[user] >= amountPerBuy[user], "insufficient balance");
        nextBuyTime[user] = block.timestamp + interval[user];
        ethBalance[user] -= amountPerBuy[user];

        (bool ok,) = dex.call{value: amountPerBuy[user]}(
            abi.encodeWithSignature("buyToken(address,address)", targetToken, user)
        );
        require(ok, "buy failed");

        totalSpent[user] += amountPerBuy[user];
        totalBuys[user] += 1;
        emit BuyExecuted(user, amountPerBuy[user], 0, block.timestamp);
    }

    function withdraw() external {
        uint256 amount = ethBalance[msg.sender];
        ethBalance[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getConfig(address user) external view returns (Config memory) {
        return Config({
            interval: interval[user],
            amountPerBuy: amountPerBuy[user],
            maxSlippageBps: maxSlippageBps[user]
        });
    }

    function setKeeper(address newKeeper) external onlyOwner {
        emit KeeperUpdated(keeper, newKeeper);
        keeper = newKeeper;
    }

    function setDex(address newDex) external onlyOwner {
        dex = newDex;
    }
}
