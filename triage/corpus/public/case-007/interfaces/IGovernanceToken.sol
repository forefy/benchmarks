// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernanceToken {
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event MintScheduleUpdated(uint256 totalMinted, uint256 remaining);
    event TransferRestrictionUpdated(bool restricted);

    error TransferRestricted();
    error CapExceeded();

    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function delegate(address delegatee) external;
    function getVotes(address account) external view returns (uint256);
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
    function remainingMintable() external view returns (uint256);
    function setTransferRestriction(bool restricted) external;
}
