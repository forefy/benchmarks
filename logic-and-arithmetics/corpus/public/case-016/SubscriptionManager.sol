// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISubscription.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract SubscriptionManager is ISubscription {
    IERC20 public immutable paymentToken;
    address public owner;
    bool public paused;
    bool private _locked;

    enum Tier { Basic, Standard, Premium }

    struct TierConfig {
        uint256 weeklyRate;
        bool active;
    }

    struct Subscription {
        uint256 expiry;
        Tier tier;
    }

    mapping(Tier => TierConfig) public tierConfigs;
    mapping(address => Subscription) public subscriptions;

    event Subscribed(address indexed user, Tier tier, uint256 numWeeks, uint256 expiry);
    event Canceled(address indexed user, uint256 refund);
    event TierConfigUpdated(Tier tier, uint256 weeklyRate, bool active);
    event Withdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event PauseToggled(bool paused);

    error Unauthorized();
    error Reentrant();
    error ContractPaused();
    error ZeroWeeks();
    error TierNotActive();
    error NoActiveSubscription();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(address _token, uint256 _basicRate, uint256 _standardRate, uint256 _premiumRate) {
        paymentToken = IERC20(_token);
        owner = msg.sender;
        tierConfigs[Tier.Basic] = TierConfig(_basicRate, true);
        tierConfigs[Tier.Standard] = TierConfig(_standardRate, true);
        tierConfigs[Tier.Premium] = TierConfig(_premiumRate, true);
    }

    function subscribe(uint256 numWeeks) external override nonReentrant whenNotPaused {
        _subscribeWithTier(numWeeks, Tier.Basic);
    }

    function subscribeWithTier(uint256 numWeeks, Tier tier) external nonReentrant whenNotPaused {
        _subscribeWithTier(numWeeks, tier);
    }

    function _subscribeWithTier(uint256 numWeeks, Tier tier) internal {
        if (numWeeks == 0) revert ZeroWeeks();
        TierConfig storage cfg = tierConfigs[tier];
        if (!cfg.active) revert TierNotActive();
        uint256 cost = cfg.weeklyRate * numWeeks;
        if (!paymentToken.transferFrom(msg.sender, address(this), cost)) revert TransferFailed();
        uint256 start = subscriptions[msg.sender].expiry > block.timestamp
            ? subscriptions[msg.sender].expiry
            : block.timestamp;
        uint256 newExpiry = start + (1 weeks * numWeeks);
        subscriptions[msg.sender] = Subscription(newExpiry, tier);
        emit Subscribed(msg.sender, tier, numWeeks, newExpiry);
    }

    function cancel() external override nonReentrant {
        Subscription storage sub = subscriptions[msg.sender];
        if (sub.expiry <= block.timestamp) revert NoActiveSubscription();
        uint256 remaining = sub.expiry - block.timestamp;
        uint256 weeklyRate = tierConfigs[sub.tier].weeklyRate;
        uint256 refund = (remaining * weeklyRate) / 1 weeks;
        sub.expiry = block.timestamp;
        if (!paymentToken.transfer(msg.sender, refund)) revert TransferFailed();
        emit Canceled(msg.sender, refund);
    }

    function isSubscribed(address user) external view override returns (bool) {
        return subscriptions[user].expiry > block.timestamp;
    }

    function expiryOf(address user) external view override returns (uint256) {
        return subscriptions[user].expiry;
    }

    function tierOf(address user) external view returns (Tier) {
        return subscriptions[user].tier;
    }

    function remainingTime(address user) external view returns (uint256) {
        uint256 expiry = subscriptions[user].expiry;
        if (expiry <= block.timestamp) return 0;
        return expiry - block.timestamp;
    }

    function setTierConfig(Tier tier, uint256 weeklyRate, bool active) external onlyOwner {
        tierConfigs[tier] = TierConfig(weeklyRate, active);
        emit TierConfigUpdated(tier, weeklyRate, active);
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        if (!paymentToken.transfer(owner, amount)) revert TransferFailed();
        emit Withdrawn(owner, amount);
    }

    function withdrawAll() external onlyOwner nonReentrant {
        uint256 balance = paymentToken.balanceOf(address(this));
        if (!paymentToken.transfer(owner, balance)) revert TransferFailed();
        emit Withdrawn(owner, balance);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseToggled(_paused);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
