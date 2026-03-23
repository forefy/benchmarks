// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SignatureLib {
    error InvalidSignatureLength(uint256 length);

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        if (sig.length != 65) revert InvalidSignatureLength(sig.length);
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

    function recoverWithPrefix(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        return recover(toEthSignedMessageHash(hash), sig);
    }
}
