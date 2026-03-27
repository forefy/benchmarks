// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernance {
    function propose(string calldata description) external returns (uint256 id);
    function castVote(uint256 proposalId, bool support) external;
    function execute(uint256 proposalId) external;
    function cancel(uint256 proposalId) external;
}
