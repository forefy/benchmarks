// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ExchangeRouter {
    uint256 public reserveETH;
    uint256 public reserveToken;
    address public feeTo;
    uint256 public constant FEE_BIPS = 30;

    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool ethToToken);

    constructor() payable {
        reserveETH = msg.value;
        reserveToken = 1_000_000 ether;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeTo || feeTo == address(0), "not authorized");
        feeTo = _feeTo;
    }

    function addLiquidity() external payable {
        require(msg.value > 0, "no ETH");
        uint256 tokenAmount = (msg.value * reserveToken) / reserveETH;
        reserveETH += msg.value;
        reserveToken += tokenAmount;
        emit LiquidityAdded(msg.sender, msg.value, tokenAmount);
    }

    function removeLiquidity(uint256 ethAmount) external {
        require(msg.sender == feeTo, "not feeTo");
        require(ethAmount <= reserveETH, "exceeds reserve");
        uint256 tokenAmount = (ethAmount * reserveToken) / reserveETH;
        reserveETH -= ethAmount;
        reserveToken -= tokenAmount;
        (bool ok,) = msg.sender.call{value: ethAmount}("");
        require(ok);
        emit LiquidityRemoved(msg.sender, ethAmount);
    }

    function getPrice() public view returns (uint256) {
        return (reserveETH * 1e18) / reserveToken;
    }

    function swapETHForToken(uint256 minTokenOut) external payable returns (uint256 tokenOut) {
        tokenOut = (msg.value * reserveToken) / reserveETH;
        require(tokenOut >= minTokenOut, "slippage");
        reserveETH += msg.value;
        reserveToken -= tokenOut;
        emit Swap(msg.sender, msg.value, tokenOut, true);
    }

    function swapTokenForETH(uint256 tokenIn, uint256 minETHOut) external returns (uint256 ethOut) {
        ethOut = (tokenIn * reserveETH) / reserveToken;
        require(ethOut >= minETHOut, "slippage");
        reserveToken += tokenIn;
        reserveETH -= ethOut;
        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok);
        emit Swap(msg.sender, tokenIn, ethOut, false);
    }
}

contract LendingPool {
    ExchangeRouter public oracle;
    mapping(address => uint256) public collateralToken;
    mapping(address => uint256) public debtETH;

    event CollateralDeposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);

    constructor(ExchangeRouter _oracle) {
        oracle = _oracle;
    }

    function depositCollateral(uint256 tokenAmount) external {
        collateralToken[msg.sender] += tokenAmount;
        emit CollateralDeposited(msg.sender, tokenAmount);
    }

    function borrow(uint256 ethAmount) external {
        uint256 price = oracle.getPrice();
        uint256 collateralValueETH = (collateralToken[msg.sender] * price) / 1e18;
        require(collateralValueETH >= ethAmount * 2, "undercollateralized");
        debtETH[msg.sender] += ethAmount;
        (bool ok,) = msg.sender.call{value: ethAmount}("");
        require(ok);
        emit Borrowed(msg.sender, ethAmount);
    }

    function repay() external payable {
        uint256 repayAmount = msg.value;
        if (repayAmount > debtETH[msg.sender]) {
            repayAmount = debtETH[msg.sender];
        }
        debtETH[msg.sender] -= repayAmount;
        if (msg.value > repayAmount) {
            (bool ok,) = msg.sender.call{value: msg.value - repayAmount}("");
            require(ok);
        }
        emit Repaid(msg.sender, repayAmount);
    }

    receive() external payable {}
}
