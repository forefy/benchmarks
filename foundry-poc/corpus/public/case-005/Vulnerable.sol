// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingPool {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;

    function deposit() external payable {
        uint256 newShares;
        if (totalShares == 0) {
            newShares = msg.value;
        } else {
            newShares = (msg.value * totalShares) / totalAssets;
        }
        shares[msg.sender] += newShares;
        totalShares += newShares;
        totalAssets += msg.value;
    }

    function withdraw(uint256 shareAmount) external {
        require(shares[msg.sender] >= shareAmount, "insufficient shares");
        uint256 ethOut = (shareAmount * totalAssets) / totalShares;
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalAssets -= ethOut;
        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok);
    }

    receive() external payable {}
}
