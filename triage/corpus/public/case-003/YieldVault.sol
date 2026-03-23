// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IYieldVault.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStrategy {
    function invest(uint256 amount) external;
    function divest(uint256 amount) external;
    function totalValue() external view returns (uint256);
    function emergencyWithdraw() external returns (uint256);
}

contract YieldVault is ERC20, Ownable, ReentrancyGuard, IYieldVault {
    IERC20 public asset;
    IStrategy public strategy;

    uint256 public constant WITHDRAWAL_FEE_BPS = 10;
    uint256 public constant PERFORMANCE_FEE_BPS = 1000;
    uint256 public constant BPS_DENOMINATOR = 10000;

    bool public emergencyExit;

    uint256 public lastHarvestTimestamp;
    uint256 public totalFeesCollected;
    uint256 public totalHarvestProfit;

    modifier notEmergency() {
        if (emergencyExit) revert EmergencyMode();
        _;
    }

    constructor(address _asset, address _strategy)
        ERC20("Vault Share", "vSHARE")
        Ownable(msg.sender)
    {
        asset = IERC20(_asset);
        strategy = IStrategy(_strategy);
        lastHarvestTimestamp = block.timestamp;
    }

    function deposit(uint256 amount) external nonReentrant notEmergency returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();
        uint256 totalAssets_ = totalAssets();
        uint256 supply = totalSupply();
        shares = supply == 0 ? amount : (amount * supply) / totalAssets_;
        asset.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, shares);
        strategy.invest(amount);
        emit Deposited(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
        if (shares == 0) revert ZeroAmount();
        uint256 totalAssets_ = totalAssets();
        amount = (shares * totalAssets_) / totalSupply();
        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / BPS_DENOMINATOR;
        _burn(msg.sender, shares);
        if (!emergencyExit) {
            strategy.divest(amount);
        }
        asset.transfer(msg.sender, amount - fee);
        if (fee > 0) {
            asset.transfer(owner(), fee);
            totalFeesCollected += fee;
        }
        emit Withdrawn(msg.sender, shares, amount - fee, fee);
    }

    function harvest() external onlyOwner {
        uint256 before = asset.balanceOf(address(this)) + strategy.totalValue();
        uint256 profit = before > totalAssets() ? before - totalAssets() : 0;
        if (profit > 0) {
            uint256 fee = (profit * PERFORMANCE_FEE_BPS) / BPS_DENOMINATOR;
            totalFeesCollected += fee;
            totalHarvestProfit += profit;
            asset.transfer(owner(), fee);
            emit Harvested(profit, fee);
        }
        lastHarvestTimestamp = block.timestamp;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + strategy.totalValue();
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        return (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return shares;
        return (shares * totalAssets()) / supply;
    }

    function setStrategy(address newStrategy) external onlyOwner {
        address old = address(strategy);
        strategy.divest(strategy.totalValue());
        strategy = IStrategy(newStrategy);
        uint256 bal = asset.balanceOf(address(this));
        if (bal > 0) strategy.invest(bal);
        emit StrategyUpdated(old, newStrategy);
    }

    function triggerEmergencyExit() external onlyOwner {
        emergencyExit = true;
        strategy.emergencyWithdraw();
        emit EmergencyExitTriggered(msg.sender);
    }

    function pricePerShare() external view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1e18;
        return (totalAssets() * 1e18) / supply;
    }
}
