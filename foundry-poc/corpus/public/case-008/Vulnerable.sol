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

interface IYieldStrategy {
    function deploy(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalValue() external view returns (uint256);
}

contract YieldVault {
    IERC20 public token;
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    IYieldStrategy public strategy;
    address public manager;
    uint256 public managementFeeBips;
    uint256 public constant MAX_FEE_BIPS = 1000;

    event Deposited(address indexed user, uint256 assets, uint256 sharesOut);
    event Redeemed(address indexed user, uint256 shareAmount, uint256 assetsOut);
    event Donated(address indexed donor, uint256 amount);
    event StrategySet(address indexed strategy);
    event ManagerChanged(address indexed previous, address indexed next);
    event FeeUpdated(uint256 feeBips);

    modifier onlyManager() {
        require(msg.sender == manager, "not manager");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        manager = msg.sender;
        managementFeeBips = 50;
    }

    function setManager(address newManager) external onlyManager {
        emit ManagerChanged(manager, newManager);
        manager = newManager;
    }

    function setStrategy(address _strategy) external onlyManager {
        strategy = IYieldStrategy(_strategy);
        emit StrategySet(_strategy);
    }

    function setManagementFee(uint256 feeBips) external onlyManager {
        require(feeBips <= MAX_FEE_BIPS, "fee too high");
        managementFeeBips = feeBips;
        emit FeeUpdated(feeBips);
    }

    function deployToStrategy(uint256 amount) external onlyManager {
        strategy.deploy(amount);
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
        emit Deposited(msg.sender, assets, sharesOut);
    }

    function redeem(uint256 shareAmount) external returns (uint256 assetsOut) {
        assetsOut = (shareAmount * totalAssets()) / totalShares;
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        token.transfer(msg.sender, assetsOut);
        emit Redeemed(msg.sender, shareAmount, assetsOut);
    }

    function donate(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        emit Donated(msg.sender, amount);
    }
}
