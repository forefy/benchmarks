// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract InterestRateModel {
    uint256 public constant BASE_RATE = 2e16;
    uint256 public constant MULTIPLIER = 1e17;
    uint256 public constant JUMP_MULTIPLIER = 1e18;
    uint256 public constant KINK = 8e17;
    uint256 public constant SCALE = 1e18;

    event RateComputed(uint256 utilizationRate, uint256 borrowRate);

    function getBorrowRate(uint256 cash, uint256 borrows) external returns (uint256) {
        uint256 utilization = borrows == 0 ? 0 : borrows * SCALE / (cash + borrows);
        uint256 rate;
        if (utilization <= KINK) {
            rate = BASE_RATE + utilization * MULTIPLIER / SCALE;
        } else {
            uint256 normalRate = BASE_RATE + KINK * MULTIPLIER / SCALE;
            uint256 excessUtil = utilization - KINK;
            rate = normalRate + excessUtil * JUMP_MULTIPLIER / SCALE;
        }
        emit RateComputed(utilization, rate);
        return rate;
    }

    function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserveFactor) external view returns (uint256) {
        uint256 utilization = borrows == 0 ? 0 : borrows * SCALE / (cash + borrows);
        uint256 borrowRate;
        if (utilization <= KINK) {
            borrowRate = BASE_RATE + utilization * MULTIPLIER / SCALE;
        } else {
            uint256 normalRate = BASE_RATE + KINK * MULTIPLIER / SCALE;
            uint256 excessUtil = utilization - KINK;
            borrowRate = normalRate + excessUtil * JUMP_MULTIPLIER / SCALE;
        }
        return borrowRate * utilization / SCALE * (SCALE - reserveFactor) / SCALE;
    }

    function utilizationRate(uint256 cash, uint256 borrows) external pure returns (uint256) {
        if (borrows == 0) return 0;
        return borrows * SCALE / (cash + borrows);
    }
}
