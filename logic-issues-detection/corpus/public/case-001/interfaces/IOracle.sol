// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    function update() external;
    function getPrice() external view returns (uint256);
    function spotPrice() external view returns (uint256);
    function lastUpdateBlock() external view returns (uint256);
}
