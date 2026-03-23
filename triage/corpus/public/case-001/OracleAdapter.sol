// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}

contract OracleAdapter {
    address public immutable owner;
    uint256 public constant STALE_THRESHOLD = 1 hours;

    mapping(address => address) public feeds;
    mapping(address => uint256) public fallbackPrices;

    event FeedRegistered(address indexed token, address indexed feed);
    event FallbackPriceSet(address indexed token, uint256 price);

    error StalePrice(address token);
    error NoPriceFeed(address token);
    error NegativePrice(address token);
    error Unauthorized();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerFeed(address token, address feed) external onlyOwner {
        feeds[token] = feed;
        emit FeedRegistered(token, feed);
    }

    function setFallbackPrice(address token, uint256 price) external onlyOwner {
        fallbackPrices[token] = price;
        emit FallbackPriceSet(token, price);
    }

    function getPrice(address token) external view returns (uint256) {
        address feed = feeds[token];
        if (feed == address(0)) {
            uint256 fb = fallbackPrices[token];
            if (fb == 0) revert NoPriceFeed(token);
            return fb;
        }
        IAggregatorV3 agg = IAggregatorV3(feed);
        (, int256 answer,, uint256 updatedAt,) = agg.latestRoundData();
        if (block.timestamp - updatedAt > STALE_THRESHOLD) revert StalePrice(token);
        if (answer <= 0) revert NegativePrice(token);
        uint8 dec = agg.decimals();
        return uint256(answer) * 1e18 / (10 ** dec);
    }

    function hasFeed(address token) external view returns (bool) {
        return feeds[token] != address(0) || fallbackPrices[token] != 0;
    }
}
