// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract BondingCurve {
    IERC20 public reserve;
    uint256 public totalSupply;
    uint256 public reserveBalance;
    uint32 public constant RESERVE_RATIO = 500_000;
    uint256 public constant SCALE = 1_000_000;

    function buy(uint256 reserveAmount, uint256 minTokens) external returns (uint256 tokensOut) {
        reserve.transferFrom(msg.sender, address(this), reserveAmount);
        reserveBalance += reserveAmount;
        if (totalSupply == 0) {
            tokensOut = reserveAmount;
        } else {
            tokensOut = totalSupply * (
                _sqrt(reserveBalance * SCALE / (reserveBalance - reserveAmount)) - SCALE
            ) / SCALE;
        }
        require(tokensOut >= minTokens, 'slippage');
        totalSupply += tokensOut;
    }

    function sell(uint256 tokenAmount, uint256 minReserve) external returns (uint256 reserveOut) {
        require(tokenAmount <= totalSupply, 'exceeds supply');
        reserveOut = reserveBalance * tokenAmount / totalSupply;
        require(reserveOut >= minReserve, 'slippage');
        totalSupply -= tokenAmount;
        reserveBalance -= reserveOut;
        reserve.transfer(msg.sender, reserveOut);
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
