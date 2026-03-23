// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Collateralized lending. Users deposit ETH as collateral and borrow ERC20.
// Interest accrues per block. A liquidation bot can repay debt and claim
// collateral at a discount when health factor drops below 1.0.
contract CollateralVault {
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
    uint256 public ethPrice;
    address public oracle;

    mapping(address => Account) public accounts;

    constructor(address _debtToken, address _oracle) {
        debtToken = IERC20(_debtToken);
        oracle = _oracle;
        lastAccrualBlock = block.number;
    }

    function _accrueInterest() internal {
        uint256 blocks = block.number - lastAccrualBlock;
        if (blocks == 0) return;
        globalInterestIndex += globalInterestIndex * INTEREST_PER_BLOCK * blocks / 1e18;
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
        _accrueInterest();
        accounts[msg.sender].collateral += msg.value;
    }

    function borrow(uint256 amount) external {
        _accrueInterest();
        Account storage a = accounts[msg.sender];
        a.principal = currentDebt(msg.sender);
        a.interestIndex = globalInterestIndex;
        a.principal += amount;
        require(healthFactor(msg.sender) >= 1e18, "undercollateralized");
        debtToken.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        _accrueInterest();
        Account storage a = accounts[msg.sender];
        uint256 debt = currentDebt(msg.sender);
        uint256 repaid = amount > debt ? debt : amount;
        debtToken.transferFrom(msg.sender, address(this), repaid);
        a.principal = debt - repaid;
        a.interestIndex = globalInterestIndex;
    }

    function liquidate(address user, uint256 repayAmount) external {
        _accrueInterest();
        require(healthFactor(user) < 1e18, "healthy");
        Account storage a = accounts[user];
        uint256 debt = currentDebt(user);
        require(repayAmount <= debt, "exceeds debt");
        debtToken.transferFrom(msg.sender, address(this), repayAmount);
        a.principal = debt - repayAmount;
        a.interestIndex = globalInterestIndex;
        uint256 collateralValue = repayAmount * 1e18 / ethPrice;
        uint256 bonus = collateralValue * LIQUIDATION_BONUS_BPS / 10000;
        uint256 seized = collateralValue + bonus;
        if (seized > a.collateral) seized = a.collateral;
        a.collateral -= seized;
        (bool ok,) = msg.sender.call{value: seized}("");
        require(ok, "transfer failed");
    }

    function updatePrice(uint256 newPrice) external {
        require(msg.sender == oracle, "not oracle");
        ethPrice = newPrice;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
