// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Token bridge. Relayers submit merkle proofs of deposits on the source chain
// and the bridge mints wrapped tokens on this chain.
contract TokenBridge {
    address public owner;
    mapping(bytes32 => bool) public claimed;

    IERC20Mintable public wrappedToken;

    constructor(address _token) {
        owner = msg.sender;
        wrappedToken = IERC20Mintable(_token);
    }

    function claim(
        address recipient,
        uint256 amount,
        bytes32 depositId,
        bytes32[] calldata proof
    ) external {
        require(!claimed[depositId], "already claimed");
        require(_verify(proof, depositId, recipient, amount), "invalid proof");
        claimed[depositId] = true;
        wrappedToken.mint(recipient, amount);
    }

    function _verify(
        bytes32[] calldata proof,
        bytes32 depositId,
        address recipient,
        uint256 amount
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(depositId, recipient, amount));
        bytes32 root = merkleRoot();
        for (uint256 i = 0; i < proof.length; i++) {
            if (leaf < proof[i]) {
                leaf = keccak256(abi.encodePacked(leaf, proof[i]));
            } else {
                leaf = keccak256(abi.encodePacked(proof[i], leaf));
            }
        }
        return leaf == root;
    }

    function merkleRoot() public view returns (bytes32) {
        return bytes32(0);
    }

    function syncRoot(bytes32 newRoot) external {
        merkleRoot = newRoot;
    }
}

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}
