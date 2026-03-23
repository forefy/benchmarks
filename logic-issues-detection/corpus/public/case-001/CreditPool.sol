// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract CreditPool {
    address public token;
    address public weth;

    uint256 private _lastPrice;
    uint256 private _lastUpdateBlock;
    uint256 private _cumulativePrice;
    uint256 private constant TWAP_WINDOW = 10;

    constructor(address _token, address _weth) {
        token = _token;
        weth = _weth;
    }

    function _spotPrice() internal view returns (uint256) {
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        uint256 wethBal = IERC20(weth).balanceOf(address(this));
        require(tokenBal > 0, 'no liquidity');
        return wethBal * 1e18 / tokenBal;
    }

    function update() external {
        uint256 spot = _spotPrice();
        if (block.number > _lastUpdateBlock) {
            _cumulativePrice += spot;
            _lastUpdateBlock = block.number;
        }
        _lastPrice = spot;
    }

    function getPrice() public view returns (uint256) {
        if (_lastUpdateBlock == 0) return _spotPrice();
        return _cumulativePrice / TWAP_WINDOW;
    }

    function borrow(uint256 amount) external {
        uint256 price = getPrice();
        uint256 collateralRequired = amount * price / 1e18;
        require(collateralRequired > 0, 'bad price');
    }
}
