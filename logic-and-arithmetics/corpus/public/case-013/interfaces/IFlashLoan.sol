// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoan {
    function flashLoan(uint256 amount, bytes calldata data) external;
    function maxFlashLoan() external view returns (uint256);
    function flashFee(uint256 amount) external view returns (uint256);
}

interface IFlashBorrower {
    function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external;
}
