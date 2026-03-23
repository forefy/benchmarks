// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Yield aggregator vault. Users deposit USDC, vault auto-compounds into a strategy.
// Withdrawal fee of 0.1% discourages flash deposits.
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract YieldVault is ERC20, Ownable, ReentrancyGuard {
    IERC20 public asset;
    IStrategy public strategy;
    uint256 public constant WITHDRAWAL_FEE_BPS = 10;

    constructor(address _asset, address _strategy)
        ERC20("Vault Share", "vSHARE")
        Ownable(msg.sender)
    {
        asset = IERC20(_asset);
        strategy = IStrategy(_strategy);
    }

    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        uint256 totalAssets_ = totalAssets();
        uint256 supply = totalSupply();
        shares = supply == 0 ? amount : (amount * supply) / totalAssets_;
        asset.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, shares);
        strategy.invest(amount);
    }

    function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
        uint256 totalAssets_ = totalAssets();
        amount = (shares * totalAssets_) / totalSupply();
        uint256 fee = (amount * WITHDRAWAL_FEE_BPS) / 10000;
        _burn(msg.sender, shares);
        strategy.divest(amount);
        asset.transfer(msg.sender, amount - fee);
        asset.transfer(owner(), fee);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + strategy.totalValue();
    }

    function setStrategy(address newStrategy) external onlyOwner {
        strategy = IStrategy(newStrategy);
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStrategy {
    function invest(uint256 amount) external;
    function divest(uint256 amount) external;
    function totalValue() external view returns (uint256);
}
