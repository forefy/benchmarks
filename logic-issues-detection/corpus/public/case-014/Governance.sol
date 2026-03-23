// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IGovernance.sol";

interface IVotingToken {
    function balanceOf(address account) external view returns (uint256);
}

contract Governance is IGovernance {
    enum ProposalState { Pending, Active, Succeeded, Defeated, Executed, Canceled }

    struct Proposal {
        address proposer;
        string description;
        uint256 snapshotBlock;
        uint256 votingStart;
        uint256 votingEnd;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    IVotingToken public immutable token;
    address public owner;
    uint256 public proposalCount;
    uint256 public proposalThreshold;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => uint256) public executionTime;

    uint256 public constant VOTING_PERIOD = 100;
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant QUORUM = 1000e18;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string description, uint256 snapshotBlock, uint256 votingEnd);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalQueued(uint256 indexed id, uint256 eta);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCanceled(uint256 indexed id);
    event ThresholdUpdated(uint256 newThreshold);

    error Unauthorized();
    error BelowThreshold();
    error VotingEnded();
    error VotingNotEnded();
    error AlreadyVoted();
    error AlreadyExecuted();
    error QuorumNotMet();
    error ProposalDefeated();
    error TimelockPending();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address _token, uint256 _proposalThreshold) {
        token = IVotingToken(_token);
        owner = msg.sender;
        proposalThreshold = _proposalThreshold;
    }

    function propose(string calldata description) external override returns (uint256 id) {
        if (token.balanceOf(msg.sender) < proposalThreshold) revert BelowThreshold();
        id = proposalCount++;
        Proposal storage p = proposals[id];
        p.proposer = msg.sender;
        p.description = description;
        p.snapshotBlock = block.number;
        p.votingStart = block.number + VOTING_DELAY;
        p.votingEnd = block.number + VOTING_DELAY + VOTING_PERIOD;
        emit ProposalCreated(id, msg.sender, description, block.number, p.votingEnd);
    }

    function castVote(uint256 proposalId, bool support) external override {
        Proposal storage p = proposals[proposalId];
        require(block.number <= p.votingEnd, "voting ended");
        require(!p.hasVoted[msg.sender], "already voted");
        p.hasVoted[msg.sender] = true;
        uint256 weight = token.balanceOf(msg.sender);
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function queue(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        if (block.number <= p.votingEnd) revert VotingNotEnded();
        if (p.executed || p.canceled) revert AlreadyExecuted();
        if (p.forVotes + p.againstVotes < QUORUM) revert QuorumNotMet();
        if (p.forVotes <= p.againstVotes) revert ProposalDefeated();
        executionTime[proposalId] = block.timestamp + TIMELOCK_DELAY;
        emit ProposalQueued(proposalId, executionTime[proposalId]);
    }

    function execute(uint256 proposalId) external override {
        Proposal storage p = proposals[proposalId];
        require(block.number > p.votingEnd, "not ended");
        require(!p.executed, "already executed");
        require(p.forVotes + p.againstVotes >= QUORUM, "quorum not met");
        require(p.forVotes > p.againstVotes, "defeated");
        if (executionTime[proposalId] > 0) {
            require(block.timestamp >= executionTime[proposalId], "timelock active");
        }
        p.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external override {
        Proposal storage p = proposals[proposalId];
        if (msg.sender != p.proposer && msg.sender != owner) revert Unauthorized();
        if (p.executed) revert AlreadyExecuted();
        p.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function state(uint256 proposalId) external view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (block.number <= p.votingEnd) return ProposalState.Active;
        if (p.forVotes + p.againstVotes < QUORUM || p.forVotes <= p.againstVotes) return ProposalState.Defeated;
        return ProposalState.Succeeded;
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function setProposalThreshold(uint256 _threshold) external onlyOwner {
        proposalThreshold = _threshold;
        emit ThresholdUpdated(_threshold);
    }
}
