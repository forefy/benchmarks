// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IOracle.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract PriceAccumulator is IOracle {
    address public immutable token;
    address public immutable weth;

    uint256 private _lastPrice;
    uint256 private _lastUpdateBlock;
    uint256 private _cumulativePrice;

    uint256 private constant TWAP_WINDOW = 10;

    event PriceUpdated(uint256 spot, uint256 blockNumber);

    error NoLiquidity();

    constructor(address _token, address _weth) {
        token = _token;
        weth = _weth;
    }

    function spotPrice() external view override returns (uint256) {
        return _spotPrice();
    }

    function lastUpdateBlock() external view override returns (uint256) {
        return _lastUpdateBlock;
    }

    function cumulativePrice() external view returns (uint256) {
        return _cumulativePrice;
    }

    function _spotPrice() internal view returns (uint256) {
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        uint256 wethBal = IERC20(weth).balanceOf(address(this));
        if (tokenBal == 0) revert NoLiquidity();
        return wethBal * 1e18 / tokenBal;
    }

    function update() external override {
        uint256 spot = _spotPrice();
        if (block.number > _lastUpdateBlock) {
            _cumulativePrice += spot;
            _lastUpdateBlock = block.number;
        }
        _lastPrice = spot;
        emit PriceUpdated(spot, block.number);
    }

    function getPrice() public view override returns (uint256) {
        if (_lastUpdateBlock == 0) return _spotPrice();
        return _cumulativePrice / TWAP_WINDOW;
    }
}
