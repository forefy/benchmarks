// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FundingCalculator {
    uint256 public constant FUNDING_PRECISION = 1e18;
    uint256 public constant FUNDING_PERIOD = 8 hours;

    int256 public cumulativeFundingRate;
    uint256 public lastFundingTime;

    mapping(uint256 => int256) public fundingRateAtOpen;

    event FundingRateUpdated(int256 rate, int256 cumulative, uint256 timestamp);

    error StaleUpdate();

    constructor() {
        lastFundingTime = block.timestamp;
    }

    function recordOpen(uint256 positionId) external {
        fundingRateAtOpen[positionId] = cumulativeFundingRate;
    }

    function applyFunding(uint256 positionId, int256 size) external view returns (int256 fundingPayment) {
        int256 rateDelta = cumulativeFundingRate - fundingRateAtOpen[positionId];
        fundingPayment = (size * rateDelta) / int256(FUNDING_PRECISION);
    }

    function updateFundingRate(int256 markPrice, int256 indexPrice) external {
        if (block.timestamp < lastFundingTime + FUNDING_PERIOD) revert StaleUpdate();
        int256 premium = markPrice - indexPrice;
        int256 rate = (premium * int256(FUNDING_PRECISION)) / indexPrice / 8;
        cumulativeFundingRate += rate;
        lastFundingTime = block.timestamp;
        emit FundingRateUpdated(rate, cumulativeFundingRate, block.timestamp);
    }

    function pendingFunding(uint256 positionId, int256 size) external view returns (int256) {
        int256 rateDelta = cumulativeFundingRate - fundingRateAtOpen[positionId];
        return (size * rateDelta) / int256(FUNDING_PRECISION);
    }
}
