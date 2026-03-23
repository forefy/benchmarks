// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVotingToken {
    function balanceOf(address account) external view returns (uint256);
}

contract Governance {
    struct Proposal {
        address proposer;
        string description;
        uint256 snapshotBlock;
        uint256 votingEnd;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    IVotingToken public token;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    uint256 public constant VOTING_PERIOD = 100;
    uint256 public constant QUORUM = 1000e18;

    constructor(address _token) {
        token = _token;
    }

    function propose(string calldata description) external returns (uint256 id) {
        id = proposalCount++;
        Proposal storage p = proposals[id];
        p.proposer = msg.sender;
        p.description = description;
        p.snapshotBlock = block.number;
        p.votingEnd = block.number + VOTING_PERIOD;
    }

    function castVote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(block.number <= p.votingEnd, 'voting ended');
        require(!p.hasVoted[msg.sender], 'already voted');
        p.hasVoted[msg.sender] = true;
        uint256 weight = token.balanceOf(msg.sender);
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.number > p.votingEnd, 'not ended');
        require(!p.executed, 'already executed');
        require(p.forVotes + p.againstVotes >= QUORUM, 'quorum not met');
        require(p.forVotes > p.againstVotes, 'defeated');
        p.executed = true;
    }
}
