// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IGovernanceToken.sol";

contract GovernanceToken is ERC20, Ownable, IGovernanceToken {
    uint256 public constant MAX_SUPPLY = 100_000_000e18;
    uint256 public constant INITIAL_SUPPLY = 10_000_000e18;

    mapping(address => address) public delegates;
    mapping(address => uint256) public votingPower;
    mapping(address => mapping(uint256 => uint256)) public checkpoints;
    mapping(address => uint256) public numCheckpoints;
    mapping(address => uint256) public nonces;

    bool public transfersRestricted;

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event MintScheduleUpdated(uint256 totalMinted, uint256 remaining);
    event TransferRestrictionUpdated(bool restricted);

    error TransferRestricted();
    error CapExceeded();

    modifier whenTransferAllowed(address from) {
        if (transfersRestricted && from != owner() && from != address(0)) revert TransferRestricted();
        _;
    }

    constructor() ERC20("Governance Token", "GOV") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
        delegates[msg.sender] = msg.sender;
        votingPower[msg.sender] = INITIAL_SUPPLY;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "cap exceeded");
        _mint(to, amount);
        emit MintScheduleUpdated(totalSupply(), MAX_SUPPLY - totalSupply());
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender];
        uint256 balance = balanceOf(msg.sender);
        delegates[msg.sender] = delegatee;

        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, balance);
    }

    function getVotes(address account) external view returns (uint256) {
        return votingPower[account];
    }

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "not yet determined");
        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) return 0;
        if (checkpoints[account][nCheckpoints - 1] <= blockNumber) {
            return votingPower[account];
        }
        return 0;
    }

    function remainingMintable() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    function setTransferRestriction(bool restricted) external onlyOwner {
        transfersRestricted = restricted;
        emit TransferRestrictionUpdated(restricted);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (transfersRestricted && from != address(0) && from != owner()) revert TransferRestricted();
        super._update(from, to, amount);
        _moveDelegates(delegates[from], delegates[to], amount);
    }

    function _moveDelegates(address from, address to, uint256 amount) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                uint256 prev = votingPower[from];
                votingPower[from] = prev > amount ? prev - amount : 0;
                uint256 cp = numCheckpoints[from];
                checkpoints[from][cp] = block.number;
                numCheckpoints[from] = cp + 1;
                emit DelegateVotesChanged(from, prev, votingPower[from]);
            }
            if (to != address(0)) {
                uint256 prev = votingPower[to];
                votingPower[to] = prev + amount;
                uint256 cp = numCheckpoints[to];
                checkpoints[to][cp] = block.number;
                numCheckpoints[to] = cp + 1;
                emit DelegateVotesChanged(to, prev, votingPower[to]);
            }
        }
    }

    function supplyStats() external view returns (uint256 total, uint256 minted, uint256 remaining) {
        total = MAX_SUPPLY;
        minted = totalSupply();
        remaining = MAX_SUPPLY - minted;
    }

    function delegateOnBehalf(address delegator, address delegatee, bytes calldata sig) external {
        bytes32 structHash = keccak256(abi.encodePacked(delegator, delegatee, nonces[delegator]++));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", structHash));
        address recovered = _recoverSig(digest, sig);
        require(recovered == delegator, "invalid sig");
        address currentDelegate = delegates[delegator];
        delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, balanceOf(delegator));
    }

    function _recoverSig(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "bad sig length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(digest, v, r, s);
    }
}
