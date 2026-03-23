// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeValidator {
    address public immutable bridge;
    uint256 public constant MAX_PROOF_DEPTH = 32;

    error InvalidProofDepth(uint256 depth);
    error ZeroBridge();

    constructor(address _bridge) {
        if (_bridge == address(0)) revert ZeroBridge();
        bridge = _bridge;
    }

    function verifyProof(
        bytes32 root,
        bytes32[] calldata proof,
        bytes32 depositId,
        address recipient,
        uint256 amount
    ) external pure returns (bool) {
        if (proof.length > MAX_PROOF_DEPTH) revert InvalidProofDepth(proof.length);
        bytes32 leaf = keccak256(abi.encodePacked(depositId, recipient, amount));
        return _processProof(proof, leaf) == root;
    }

    function computeLeaf(
        bytes32 depositId,
        address recipient,
        uint256 amount
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(depositId, recipient, amount));
    }

    function _processProof(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElem = proof[i];
            if (computed <= proofElem) {
                computed = keccak256(abi.encodePacked(computed, proofElem));
            } else {
                computed = keccak256(abi.encodePacked(proofElem, computed));
            }
        }
        return computed;
    }
}
