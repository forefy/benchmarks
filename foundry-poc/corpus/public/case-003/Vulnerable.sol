// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SpotOracle {
    uint256 public reserveETH;
    uint256 public reserveToken;

    constructor() payable {
        reserveETH = msg.value;
        reserveToken = 1_000_000 ether;
    }

    function getPrice() public view returns (uint256) {
        return (reserveETH * 1e18) / reserveToken;
    }

    function swapETHForToken(uint256 minTokenOut) external payable returns (uint256 tokenOut) {
        tokenOut = (msg.value * reserveToken) / reserveETH;
        require(tokenOut >= minTokenOut, "slippage");
        reserveETH += msg.value;
        reserveToken -= tokenOut;
    }

    function swapTokenForETH(uint256 tokenIn, uint256 minETHOut) external returns (uint256 ethOut) {
        ethOut = (tokenIn * reserveETH) / reserveToken;
        require(ethOut >= minETHOut, "slippage");
        reserveToken += tokenIn;
        reserveETH -= ethOut;
        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok);
    }
}

contract LendingPool {
    SpotOracle public oracle;
    mapping(address => uint256) public collateralToken;
    mapping(address => uint256) public debtETH;

    constructor(SpotOracle _oracle) {
        oracle = _oracle;
    }

    function depositCollateral(uint256 tokenAmount) external {
        collateralToken[msg.sender] += tokenAmount;
    }

    function borrow(uint256 ethAmount) external {
        uint256 price = oracle.getPrice();
        uint256 collateralValueETH = (collateralToken[msg.sender] * price) / 1e18;
        require(collateralValueETH >= ethAmount * 2, "undercollateralized");
        debtETH[msg.sender] += ethAmount;
        (bool ok,) = msg.sender.call{value: ethAmount}("");
        require(ok);
    }

    receive() external payable {}
}
