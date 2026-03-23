// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IFlashBorrower {
    function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external;
}

contract FlashLender {
    IERC20 public token;
    uint256 public constant FEE_BPS = 30;

    constructor(address _token) {
        token = _token;
    }

    function maxFlashLoan() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function flashLoan(uint256 amount, bytes calldata data) external {
        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 fee = amount * FEE_BPS / 10_000;

        token.transfer(msg.sender, amount);
        IFlashBorrower(msg.sender).onFlashLoan(address(token), amount, fee, data);

        require(
            token.balanceOf(address(this)) >= balanceBefore - amount + fee,
            'repayment insufficient'
        );
    }
}
