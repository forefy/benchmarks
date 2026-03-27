// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IGovernor.sol";

interface IVotingToken {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
    function getVotes(address account) external view returns (uint256);
}

contract GovernorWithSnapshot is IGovernor {
    struct Proposal {
        address proposer;
        bytes32 descriptionHash;
        uint256 snapshotBlock;
        uint256 voteEnd;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        bool canceled;
    }

    IVotingToken public immutable token;
    uint256 public immutable quorum;
    uint256 public immutable votingPeriod;
    uint256 public immutable proposalThreshold;
    uint256 public immutable timelockDelay;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256) public queuedAt;
    uint256 public proposalCount;

    event Proposed(uint256 indexed id, address indexed proposer, uint256 snapshotBlock, uint256 voteEnd);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event Queued(uint256 indexed id, uint256 eta);
    event Executed(uint256 indexed id);
    event Canceled(uint256 indexed id);

    error BelowThreshold();
    error VotingEnded();
    error AlreadyVoted();
    error NoVotingPower();
    error VotingActive();
    error AlreadyExecuted();
    error QuorumNotReached();
    error Defeated();
    error TimelockPending();
    error NotQueued();
    error Unauthorized();

    constructor(
        address _token,
        uint256 _quorum,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _timelockDelay
    ) {
        token = IVotingToken(_token);
        quorum = _quorum;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        timelockDelay = _timelockDelay;
    }

    function propose(bytes32 descriptionHash) external override returns (uint256 id) {
        if (token.getVotes(msg.sender) < proposalThreshold) revert BelowThreshold();
        id = proposalCount++;
        proposals[id] = Proposal({
            proposer: msg.sender,
            descriptionHash: descriptionHash,
            snapshotBlock: block.number,
            voteEnd: block.number + votingPeriod,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            canceled: false
        });
        emit Proposed(id, msg.sender, block.number, block.number + votingPeriod);
    }

    function castVote(uint256 proposalId, bool support) external override {
        Proposal storage p = proposals[proposalId];
        if (block.number > p.voteEnd) revert VotingEnded();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        hasVoted[proposalId][msg.sender] = true;
        uint256 weight = token.getPastVotes(msg.sender, p.snapshotBlock);
        if (weight == 0) revert NoVotingPower();
        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    function queue(uint256 proposalId) external override {
        Proposal storage p = proposals[proposalId];
        if (block.number <= p.voteEnd) revert VotingActive();
        if (p.executed || p.canceled) revert AlreadyExecuted();
        if (p.votesFor < quorum) revert QuorumNotReached();
        if (p.votesFor <= p.votesAgainst) revert Defeated();
        queuedAt[proposalId] = block.timestamp;
        emit Queued(proposalId, block.timestamp + timelockDelay);
    }

    function execute(uint256 proposalId) external override {
        Proposal storage p = proposals[proposalId];
        if (block.number <= p.voteEnd) revert VotingActive();
        if (p.executed) revert AlreadyExecuted();
        if (p.votesFor < quorum) revert QuorumNotReached();
        if (p.votesFor <= p.votesAgainst) revert Defeated();
        uint256 queued = queuedAt[proposalId];
        if (queued == 0) revert NotQueued();
        if (block.timestamp < queued + timelockDelay) revert TimelockPending();
        p.executed = true;
        emit Executed(proposalId);
    }

    function cancel(uint256 proposalId) external override {
        Proposal storage p = proposals[proposalId];
        if (msg.sender != p.proposer) revert Unauthorized();
        if (p.executed) revert AlreadyExecuted();
        p.canceled = true;
        emit Canceled(proposalId);
    }

    function state(uint256 proposalId) external view returns (uint8) {
        Proposal storage p = proposals[proposalId];
        if (p.canceled) return 5;
        if (p.executed) return 4;
        if (block.number <= p.voteEnd) return 1;
        if (p.votesFor < quorum || p.votesFor <= p.votesAgainst) return 3;
        if (queuedAt[proposalId] == 0) return 2;
        return 2;
    }
}
