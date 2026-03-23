// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MetaTransferGateway {
    using ECDSA for bytes32;

    IERC20 public token;
    address public relayerFeeRecipient;
    uint256 public relayerFee = 1e16;

    constructor(address _token, address _feeRecipient) {
        token = IERC20(_token);
        relayerFeeRecipient = _feeRecipient;
    }

    function executeTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "expired");

        bytes32 digest = keccak256(abi.encodePacked(from, to, amount, deadline));
        address signer = digest.toEthSignedMessageHash().recover(signature);
        require(signer == from, "invalid signature");

        token.transferFrom(from, to, amount - relayerFee);
        token.transferFrom(from, relayerFeeRecipient, relayerFee);
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
