// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 { function balanceOf(address) external view returns (uint256); }

contract SpotPriceOracle {
    address public token;
    address public weth;

    constructor(address _token, address _weth) {
        token = _token;
        weth = _weth;
    }

    function getPrice() public view returns (uint256) {
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        uint256 wethBal = IERC20(weth).balanceOf(address(this));
        require(tokenBal > 0, 'no liquidity');
        return wethBal * 1e18 / tokenBal;
    }

    function borrow(uint256 amount) external {
        uint256 price = getPrice();
        uint256 collateralRequired = amount * price / 1e18;
        // transfer collateral check omitted for brevity
        require(collateralRequired > 0, 'bad price');
    }
}