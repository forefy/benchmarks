// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract SimpleVault {
    IERC20 public asset;
    uint256 public totalShares;

    constructor(address _asset) { asset = _asset; }

    function deposit(uint256 assets) external returns (uint256 shares) {
        uint256 supply = totalShares;
        uint256 totalAssets = asset.balanceOf(address(this));
        shares = supply == 0 ? assets : assets * supply / totalAssets;
        totalShares += shares;
        asset.transferFrom(msg.sender, address(this), assets);
    }

    function redeem(uint256 shares) external returns (uint256 assets) {
        assets = shares * asset.balanceOf(address(this)) / totalShares;
        totalShares -= shares;
        asset.transfer(msg.sender, assets);
    }
}