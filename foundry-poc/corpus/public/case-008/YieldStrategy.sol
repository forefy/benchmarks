// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract YieldStrategy {
    IERC20 public asset;
    address public vault;
    uint256 public totalDeployed;
    uint256 public yieldAccrued;

    event Deployed(uint256 amount);
    event Withdrawn(uint256 amount);
    event YieldAccrued(uint256 amount);

    modifier onlyVault() {
        require(msg.sender == vault, "not vault");
        _;
    }

    constructor(address _asset, address _vault) {
        asset = IERC20(_asset);
        vault = _vault;
    }

    function deploy(uint256 amount) external onlyVault {
        asset.transferFrom(vault, address(this), amount);
        totalDeployed += amount;
        emit Deployed(amount);
    }

    function withdraw(uint256 amount) external onlyVault {
        totalDeployed -= amount;
        asset.transfer(vault, amount);
        emit Withdrawn(amount);
    }

    function accrueYield(uint256 amount) external {
        yieldAccrued += amount;
        emit YieldAccrued(amount);
    }

    function totalValue() external view returns (uint256) {
        return totalDeployed + yieldAccrued;
    }
}
