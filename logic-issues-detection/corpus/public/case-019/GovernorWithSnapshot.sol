// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVotingToken {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}

contract GovernorWithSnapshot {
    struct Proposal {
        uint256 snapshotBlock;
        uint256 voteEnd;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    IVotingToken public immutable token;
    uint256 public immutable quorum;
    uint256 public immutable votingPeriod;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;

    event Proposed(uint256 indexed id, uint256 snapshotBlock, uint256 voteEnd);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event Executed(uint256 indexed id);

    constructor(address _token, uint256 _quorum, uint256 _votingPeriod) {
        token = IVotingToken(_token);
        quorum = _quorum;
        votingPeriod = _votingPeriod;
    }

    function propose() external returns (uint256 id) {
        id = proposalCount++;
        proposals[id] = Proposal({
            snapshotBlock: block.number,
            voteEnd: block.number + votingPeriod,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });
        emit Proposed(id, block.number, block.number + votingPeriod);
    }

    function castVote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(block.number <= p.voteEnd, 'voting ended');
        require(!hasVoted[proposalId][msg.sender], 'already voted');
        hasVoted[proposalId][msg.sender] = true;
        uint256 weight = token.getPastVotes(msg.sender, p.snapshotBlock);
        require(weight > 0, 'no voting power at snapshot');
        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.number > p.voteEnd, 'voting active');
        require(!p.executed, 'already executed');
        require(p.votesFor > p.votesAgainst, 'defeated');
        require(p.votesFor >= quorum, 'quorum not reached');
        p.executed = true;
        emit Executed(proposalId);
    }
}
