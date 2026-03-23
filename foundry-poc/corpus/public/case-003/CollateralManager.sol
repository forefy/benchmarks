// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingPool {
    function depositCollateral(uint256 tokenAmount) external;
    function borrow(uint256 ethAmount) external;
    function repay() external payable;
    function collateralToken(address user) external view returns (uint256);
}

interface IExchangeRouter {
    function getPrice() external view returns (uint256);
}

contract CollateralManager {
    ILendingPool public lendingPool;
    IExchangeRouter public exchange;
    address public governance;
    mapping(address => uint256) public positionCount;

    event PositionOpened(address indexed user, uint256 collateralAmount, uint256 borrowAmount);
    event PositionClosed(address indexed user, uint256 debtAmount);

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    constructor(address _lendingPool, address _exchange) {
        lendingPool = ILendingPool(_lendingPool);
        exchange = IExchangeRouter(_exchange);
        governance = msg.sender;
    }

    function openPosition(uint256 collateralAmount, uint256 borrowAmount) external {
        lendingPool.depositCollateral(collateralAmount);
        lendingPool.borrow(borrowAmount);
        positionCount[msg.sender] += 1;
        emit PositionOpened(msg.sender, collateralAmount, borrowAmount);
    }

    function closePosition(uint256 debtAmount) external payable {
        lendingPool.repay{value: msg.value}();
        emit PositionClosed(msg.sender, debtAmount);
    }

    function getCollateralValue(address user) external view returns (uint256) {
        uint256 collateral = lendingPool.collateralToken(user);
        uint256 price = exchange.getPrice();
        return (collateral * price) / 1e18;
    }
}
