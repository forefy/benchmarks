// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBondingCurve.sol";

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract BondingCurve is IBondingCurve {
    IERC20 public reserve;
    uint256 public totalSupply;
    uint256 public reserveBalance;
    uint32 public constant RESERVE_RATIO = 500_000;
    uint256 public constant SCALE = 1_000_000;

    address public owner;
    uint256 public feeBps;
    uint256 public accumulatedFees;
    bool private _locked;

    event TokensPurchased(address indexed buyer, uint256 reserveIn, uint256 tokensOut);
    event TokensSold(address indexed seller, uint256 tokensIn, uint256 reserveOut);
    event FeeCollected(uint256 amount);
    event FeeUpdated(uint256 newFeeBps);

    error Unauthorized();
    error Reentrant();
    error SlippageExceeded();
    error ExceedsSupply();
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

    constructor(address _reserve, uint256 _feeBps) {
        reserve = IERC20(_reserve);
        owner = msg.sender;
        feeBps = _feeBps;
    }

    function buy(uint256 reserveAmount, uint256 minTokens) external override nonReentrant returns (uint256 tokensOut) {
        reserve.transferFrom(msg.sender, address(this), reserveAmount);
        reserveBalance += reserveAmount;
        if (totalSupply == 0) {
            tokensOut = reserveAmount;
        } else {
            tokensOut = totalSupply * (
                _sqrt(reserveBalance * SCALE / (reserveBalance - reserveAmount)) - SCALE
            ) / SCALE;
        }
        require(tokensOut >= minTokens, "slippage");
        totalSupply += tokensOut;
        emit TokensPurchased(msg.sender, reserveAmount, tokensOut);
    }

    function sell(uint256 tokenAmount, uint256 minReserve) external override nonReentrant returns (uint256 reserveOut) {
        if (tokenAmount > totalSupply) revert ExceedsSupply();
        reserveOut = reserveBalance * tokenAmount / totalSupply;
        if (reserveOut < minReserve) revert SlippageExceeded();
        uint256 fee = reserveOut * feeBps / 10_000;
        accumulatedFees += fee;
        reserveOut -= fee;
        totalSupply -= tokenAmount;
        reserveBalance -= (reserveOut + fee);
        if (!reserve.transfer(msg.sender, reserveOut)) revert TransferFailed();
        emit TokensSold(msg.sender, tokenAmount, reserveOut);
    }

    function currentPrice() external view override returns (uint256) {
        if (totalSupply == 0) return SCALE;
        return reserveBalance * SCALE / totalSupply;
    }

    function spotBuyPrice(uint256 reserveAmount) external view returns (uint256) {
        if (totalSupply == 0) return reserveAmount;
        uint256 newReserve = reserveBalance + reserveAmount;
        return totalSupply * (_sqrt(newReserve * SCALE / reserveBalance) - SCALE) / SCALE;
    }

    function spotSellPrice(uint256 tokenAmount) external view returns (uint256) {
        if (totalSupply == 0) return 0;
        return reserveBalance * tokenAmount / totalSupply;
    }

    function collectFees() external onlyOwner {
        uint256 fees = accumulatedFees;
        accumulatedFees = 0;
        if (!reserve.transfer(owner, fees)) revert TransferFailed();
        emit FeeCollected(fees);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 500, "fee too high");
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
