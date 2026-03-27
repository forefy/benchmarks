// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVault.sol";

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract YieldVault is IVault {
    IERC20 public asset;
    uint256 public totalShares;

    address public owner;
    bool private _locked;
    bool public paused;

    uint256 public constant FEE_BPS = 10;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public accumulatedFees;

    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Redeemed(address indexed user, uint256 shares, uint256 assets);
    event FeeCollected(uint256 amount);
    event EmergencyPauseToggled(bool paused);

    error Unauthorized();
    error ContractPaused();
    error Reentrant();
    error ZeroShares();
    error ZeroAssets();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    constructor(address _asset) {
        asset = IERC20(_asset);
        owner = msg.sender;
    }

    function deposit(uint256 assets) external override nonReentrant whenNotPaused returns (uint256 shares) {
        uint256 supply = totalShares;
        uint256 totalAssets = asset.balanceOf(address(this));
        shares = supply == 0 ? assets : assets * supply / totalAssets;
        if (shares == 0) revert ZeroShares();
        totalShares += shares;
        if (!asset.transferFrom(msg.sender, address(this), assets)) revert TransferFailed();
        emit Deposited(msg.sender, assets, shares);
    }

    function redeem(uint256 shares) external override nonReentrant whenNotPaused returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        assets = shares * asset.balanceOf(address(this)) / totalShares;
        if (assets == 0) revert ZeroAssets();
        uint256 fee = assets * FEE_BPS / BASIS_POINTS;
        accumulatedFees += fee;
        assets -= fee;
        totalShares -= shares;
        if (!asset.transfer(msg.sender, assets)) revert TransferFailed();
        emit Redeemed(msg.sender, shares, assets);
    }

    function totalAssets() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) external view override returns (uint256) {
        uint256 supply = totalShares;
        uint256 total = asset.balanceOf(address(this));
        return supply == 0 ? assets : assets * supply / total;
    }

    function convertToAssets(uint256 shares) external view override returns (uint256) {
        if (totalShares == 0) return shares;
        return shares * asset.balanceOf(address(this)) / totalShares;
    }

    function collectFees() external onlyOwner {
        uint256 fees = accumulatedFees;
        accumulatedFees = 0;
        if (!asset.transfer(owner, fees)) revert TransferFailed();
        emit FeeCollected(fees);
    }

    function setEmergencyPause(bool _paused) external onlyOwner {
        paused = _paused;
        emit EmergencyPauseToggled(_paused);
    }
}
