// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library VaultStorage {
    struct Layout {
        address owner;
        bool initialized;
        mapping(address => uint256) balances;
        uint256 totalDeposits;
        uint256 version;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("vault.storage.layout");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
