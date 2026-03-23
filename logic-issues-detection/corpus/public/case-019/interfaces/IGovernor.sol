// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernor {
    function propose(bytes32 descriptionHash) external returns (uint256 id);
    function castVote(uint256 proposalId, bool support) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external;
    function cancel(uint256 proposalId) external;
}
