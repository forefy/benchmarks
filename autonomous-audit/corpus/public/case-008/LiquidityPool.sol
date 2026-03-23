// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LiquidityPool is ERC20, Ownable, ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE_BPS = 30;

    constructor(address _tokenA, address _tokenB)
        ERC20("LP Token", "LP")
        Ownable(msg.sender)
    {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256 lpTokens) {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 supply = totalSupply();
        if (supply == 0) {
            lpTokens = sqrt(amountA * amountB);
        } else {
            lpTokens = min(
                (amountA * supply) / reserveA,
                (amountB * supply) / reserveB
            );
        }

        reserveA += amountA;
        reserveB += amountB;
        _mint(msg.sender, lpTokens);
    }

    function removeLiquidity(uint256 lpTokens) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        uint256 supply = totalSupply();
        amountA = (lpTokens * reserveA) / supply;
        amountB = (lpTokens * reserveB) / supply;

        _burn(msg.sender, lpTokens);
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);
    }

    function swapAForB(uint256 amountAIn) external nonReentrant returns (uint256 amountBOut) {
        uint256 amountAWithFee = amountAIn * (10000 - FEE_BPS);
        amountBOut = (amountAWithFee * reserveB) / (reserveA * 10000 + amountAWithFee);

        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        reserveA += amountAIn;
        reserveB -= amountBOut;
        tokenB.transfer(msg.sender, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external nonReentrant returns (uint256 amountAOut) {
        uint256 amountBWithFee = amountBIn * (10000 - FEE_BPS);
        amountAOut = (amountBWithFee * reserveA) / (reserveB * 10000 + amountBWithFee);

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        reserveB += amountBIn;
        reserveA -= amountAOut;
        tokenA.transfer(msg.sender, amountAOut);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) { y = z; z = (x / z + z) / 2; }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
