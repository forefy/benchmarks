// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeSplitter {
    event FeeReceived(address indexed sender, uint256 amount);
    event FeeSplit(address indexed partyA, uint256 amountA, address indexed partyB, uint256 amountB);
    event PartyUpdated(bool isPartyA, address indexed oldParty, address indexed newParty);
    event SharesUpdated(uint256 newShareA, uint256 newShareB);

    error SharesMustSum100();
    error ZeroAddress();
    error Unauthorized();
    error NothingToSplit();

    function split() external;
    function updateParty(bool isPartyA, address newParty) external;
    function updateShares(uint256 newShareA, uint256 newShareB) external;
    function pendingAmount(bool isPartyA) external view returns (uint256);
}
