// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IFlashBorrower {
    function onFlashLoan(address initiator, uint256 amount, uint256 fee, bytes calldata data) external;
}

contract FlashLoanProvider {
    IERC20 public asset;
    address public governance;
    uint256 public flashFeeRate;
    uint256 public feesAccrued;

    event FlashLoan(address indexed borrower, uint256 amount, uint256 fee);
    event FeeCollected(address indexed to, uint256 amount);
    event GovernanceChanged(address indexed previous, address indexed next);

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    constructor(address _asset, uint256 _feeRate) {
        asset = IERC20(_asset);
        flashFeeRate = _feeRate;
        governance = msg.sender;
    }

    function flashLoan(uint256 amount, bytes calldata data) external {
        uint256 balanceBefore = asset.balanceOf(address(this));
        uint256 fee = (amount * flashFeeRate) / 10000;
        asset.transfer(msg.sender, amount);
        IFlashBorrower(msg.sender).onFlashLoan(msg.sender, amount, fee, data);
        uint256 balanceAfter = asset.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "flash loan not repaid");
        feesAccrued += fee;
        emit FlashLoan(msg.sender, amount, fee);
    }

    function collectFees(address to) external onlyGovernance {
        uint256 amount = feesAccrued;
        feesAccrued = 0;
        asset.transfer(to, amount);
        emit FeeCollected(to, amount);
    }

    function setFeeRate(uint256 rate) external onlyGovernance {
        flashFeeRate = rate;
    }

    function setGovernance(address newGovernance) external onlyGovernance {
        emit GovernanceChanged(governance, newGovernance);
        governance = newGovernance;
    }
}
