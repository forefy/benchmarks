// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLender {
    function flashLoan(uint256 amount, bytes calldata data) external;
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract YieldVault {
    IERC20 public token;
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function totalAssets() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function deposit(uint256 assets) external returns (uint256 sharesOut) {
        uint256 supply = totalShares;
        sharesOut = supply == 0 ? assets : (assets * supply) / totalAssets();
        token.transferFrom(msg.sender, address(this), assets);
        shares[msg.sender] += sharesOut;
        totalShares += sharesOut;
    }

    function redeem(uint256 shareAmount) external returns (uint256 assetsOut) {
        assetsOut = (shareAmount * totalAssets()) / totalShares;
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        token.transfer(msg.sender, assetsOut);
    }

    function donate(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
    }
}
