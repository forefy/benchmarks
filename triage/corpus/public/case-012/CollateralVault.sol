// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ICollateralVault.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CollateralVault is ICollateralVault {
    struct Account {
        uint256 collateral;
        uint256 principal;
        uint256 interestIndex;
    }

    IERC20 public debtToken;
    uint256 public globalInterestIndex = 1e18;
    uint256 public lastAccrualBlock;
    uint256 public constant INTEREST_PER_BLOCK = 1e12;
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant LIQUIDATION_BONUS_BPS = 500;
    uint256 public constant CLOSE_FACTOR_BPS = 5000;
    uint256 public ethPrice;
    address public oracle;
    address public immutable owner;

    mapping(address => Account) public accounts;

    uint256 public totalCollateral;
    uint256 public totalDebt;
    uint256 public totalLiquidations;

    modifier onlyOracle() {
        if (msg.sender != oracle) revert NotOracle();
        _;
    }

    modifier nonZero(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    constructor(address _debtToken, address _oracle) {
        debtToken = IERC20(_debtToken);
        oracle = _oracle;
        owner = msg.sender;
        lastAccrualBlock = block.number;
    }

    function _accrueInterest() internal {
        uint256 blocks = block.number - lastAccrualBlock;
        if (blocks == 0) return;
        uint256 newIndex = globalInterestIndex + (globalInterestIndex * INTEREST_PER_BLOCK * blocks / 1e18);
        emit InterestAccrued(newIndex, blocks);
        globalInterestIndex = newIndex;
        lastAccrualBlock = block.number;
    }

    function currentDebt(address user) public view returns (uint256) {
        Account storage a = accounts[user];
        if (a.principal == 0) return 0;
        return (a.principal * globalInterestIndex) / a.interestIndex;
    }

    function healthFactor(address user) public view returns (uint256) {
        Account storage a = accounts[user];
        if (a.collateral == 0) return 0;
        uint256 collateralValue = a.collateral * ethPrice / 1e18;
        uint256 debt = currentDebt(user);
        if (debt == 0) return type(uint256).max;
        return (collateralValue * LIQUIDATION_THRESHOLD * 1e18) / (debt * 100);
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        _accrueInterest();
        accounts[msg.sender].collateral += msg.value;
        totalCollateral += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function borrow(uint256 amount) external nonZero(amount) {
        _accrueInterest();
        Account storage a = accounts[msg.sender];
        a.principal = currentDebt(msg.sender);
        a.interestIndex = globalInterestIndex;
        a.principal += amount;
        totalDebt += amount;
        if (healthFactor(msg.sender) < 1e18) revert Undercollateralized();
        debtToken.transfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonZero(amount) {
        _accrueInterest();
        Account storage a = accounts[msg.sender];
        uint256 debt = currentDebt(msg.sender);
        uint256 repaid = amount > debt ? debt : amount;
        debtToken.transferFrom(msg.sender, address(this), repaid);
        uint256 prevDebt = a.principal;
        a.principal = debt - repaid;
        a.interestIndex = globalInterestIndex;
        totalDebt = totalDebt > repaid ? totalDebt - repaid : 0;
        emit Repaid(msg.sender, repaid, a.principal);
    }

    function liquidate(address user, uint256 repayAmount) external nonZero(repayAmount) {
        _accrueInterest();
        if (healthFactor(user) >= 1e18) revert PositionHealthy();
        Account storage a = accounts[user];
        uint256 debt = currentDebt(user);
        uint256 maxRepay = (debt * CLOSE_FACTOR_BPS) / 10000;
        if (repayAmount > maxRepay) repayAmount = maxRepay;
        if (repayAmount > debt) revert ExceedsDebt();
        debtToken.transferFrom(msg.sender, address(this), repayAmount);
        a.principal = debt - repayAmount;
        a.interestIndex = globalInterestIndex;
        totalDebt = totalDebt > repayAmount ? totalDebt - repayAmount : 0;
        uint256 collateralValue = repayAmount * 1e18 / ethPrice;
        uint256 bonus = collateralValue * LIQUIDATION_BONUS_BPS / 10000;
        uint256 seized = collateralValue + bonus;
        if (seized > a.collateral) seized = a.collateral;
        a.collateral -= seized;
        totalCollateral -= seized;
        totalLiquidations += 1;
        (bool ok,) = msg.sender.call{value: seized}("");
        if (!ok) revert TransferFailed();
        emit Liquidated(user, msg.sender, repayAmount, seized);
    }

    function updatePrice(uint256 newPrice) external onlyOracle {
        emit PriceUpdated(ethPrice, newPrice);
        ethPrice = newPrice;
    }

    function utilizationRate() external view returns (uint256) {
        if (totalCollateral == 0) return 0;
        return (totalDebt * 1e18) / totalCollateral;
    }

    function setOracle(address newOracle) external {
        require(msg.sender == owner, "not owner");
        oracle = newOracle;
    }
}
