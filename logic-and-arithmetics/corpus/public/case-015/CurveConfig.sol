// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CurveConfig {
    address public owner;

    uint256 public maxBuyAmount;
    uint256 public maxSellAmount;
    uint256 public cooldownPeriod;

    mapping(address => uint256) public lastTradeTime;

    event ConfigUpdated(uint256 maxBuyAmount, uint256 maxSellAmount, uint256 cooldownPeriod);
    event TradeRecorded(address indexed trader, uint256 timestamp);

    error Unauthorized();
    error CooldownActive();
    error ExceedsMaxBuyAmount();
    error ExceedsMaxSellAmount();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(uint256 _maxBuy, uint256 _maxSell, uint256 _cooldown) {
        owner = msg.sender;
        maxBuyAmount = _maxBuy;
        maxSellAmount = _maxSell;
        cooldownPeriod = _cooldown;
    }

    function checkAndRecordTrade(address trader, uint256 buyAmount, uint256 sellAmount) external {
        if (cooldownPeriod > 0 && block.timestamp - lastTradeTime[trader] < cooldownPeriod) {
            revert CooldownActive();
        }
        if (maxBuyAmount > 0 && buyAmount > maxBuyAmount) revert ExceedsMaxBuyAmount();
        if (maxSellAmount > 0 && sellAmount > maxSellAmount) revert ExceedsMaxSellAmount();
        lastTradeTime[trader] = block.timestamp;
        emit TradeRecorded(trader, block.timestamp);
    }

    function updateConfig(uint256 _maxBuy, uint256 _maxSell, uint256 _cooldown) external onlyOwner {
        maxBuyAmount = _maxBuy;
        maxSellAmount = _maxSell;
        cooldownPeriod = _cooldown;
        emit ConfigUpdated(_maxBuy, _maxSell, _cooldown);
    }

    function canTrade(address trader) external view returns (bool) {
        if (cooldownPeriod == 0) return true;
        return block.timestamp - lastTradeTime[trader] >= cooldownPeriod;
    }
}
