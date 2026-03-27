// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBondingCurve {
    function buy(uint256 reserveAmount, uint256 minTokens) external returns (uint256 tokensOut);
    function sell(uint256 tokenAmount, uint256 minReserve) external returns (uint256 reserveOut);
    function currentPrice() external view returns (uint256);
    function reserveBalance() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
