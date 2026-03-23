// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RewardDistributor {
    address public admin;
    mapping(bytes32 => bool) public claimed;

    constructor() {
        admin = msg.sender;
    }

    function claim(address recipient, uint256 amount, bytes calldata sig) external {
        bytes32 msgHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        address signer = _recover(ethHash, sig);
        require(signer == admin, "bad sig");
        (bool ok,) = recipient.call{value: amount}("");
        require(ok, "transfer failed");
    }

    function _recover(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(hash, v, r, s);
    }

    receive() external payable {}
}
