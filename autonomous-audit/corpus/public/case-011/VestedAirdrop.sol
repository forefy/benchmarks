// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract VestedAirdrop {
    IERC20 public token;
    bytes32 public merkleRoot;
    uint256 public vestingStart;
    uint256 public vestingDuration;

    mapping(address => uint256) public claimed;

    constructor(address _token, bytes32 _merkleRoot, uint256 _vestingDuration) {
        token = IERC20(_token);
        merkleRoot = _merkleRoot;
        vestingStart = block.timestamp;
        vestingDuration = _vestingDuration;
    }

    function claimable(address account, uint256 totalAllocation) public view returns (uint256) {
        uint256 elapsed = block.timestamp - vestingStart;
        if (elapsed >= vestingDuration) elapsed = vestingDuration;
        uint256 vested = (totalAllocation * elapsed) / vestingDuration;
        uint256 alreadyClaimed = claimed[account];
        return vested > alreadyClaimed ? vested - alreadyClaimed : 0;
    }

    function claim(uint256 totalAllocation, bytes32[] calldata proof) external {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, totalAllocation));
        require(_verify(proof, merkleRoot, leaf), "invalid proof");

        uint256 amount = claimable(msg.sender, totalAllocation);
        require(amount > 0, "nothing to claim");

        claimed[msg.sender] += amount;
        token.transfer(msg.sender, amount);
    }

    function _verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 hash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 el = proof[i];
            hash = hash <= el
                ? keccak256(abi.encodePacked(hash, el))
                : keccak256(abi.encodePacked(el, hash));
        }
        return hash == root;
    }
}
