// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IBridge.sol";

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

contract TokenBridge is IBridge {
    address public owner;

    bytes32 public merkleRoot;
    uint256 public currentEpoch;

    mapping(bytes32 => bool) public claimed;
    mapping(address => bool) public guardians;

    IERC20Mintable public wrappedToken;

    uint256 public feeBps;
    uint256 public constant MAX_FEE_BPS = 100;
    address public feeRecipient;

    uint256 public totalClaimed;
    uint256 public totalFees;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _token, address _feeRecipient, uint256 _feeBps) {
        if (_token == address(0)) revert ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        owner = msg.sender;
        wrappedToken = IERC20Mintable(_token);
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;
    }

    function addGuardian(address addr) external onlyOwner {
        guardians[addr] = true;
        emit GuardianUpdated(address(0), addr);
    }

    function removeGuardian(address addr) external onlyOwner {
        guardians[addr] = false;
        emit GuardianUpdated(addr, address(0));
    }

    function claim(
        address recipient,
        uint256 amount,
        bytes32 depositId,
        bytes32[] calldata proof
    ) external {
        if (claimed[depositId]) revert AlreadyClaimed(depositId);
        if (!_verify(proof, depositId, recipient, amount)) revert InvalidProof(depositId);
        claimed[depositId] = true;
        totalClaimed += amount;
        uint256 fee = (amount * feeBps) / 10000;
        if (fee > 0) {
            totalFees += fee;
            wrappedToken.mint(feeRecipient, fee);
            emit FeeCollected(feeRecipient, fee);
        }
        wrappedToken.mint(recipient, amount - fee);
        emit Claimed(depositId, recipient, amount - fee);
    }

    function syncRoot(bytes32 newRoot) external {
        merkleRoot = newRoot;
        currentEpoch += 1;
        emit RootSynced(newRoot, currentEpoch);
    }

    function _verify(
        bytes32[] calldata proof,
        bytes32 depositId,
        address recipient,
        uint256 amount
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(depositId, recipient, amount));
        bytes32 root = merkleRoot;
        for (uint256 i = 0; i < proof.length; i++) {
            if (leaf < proof[i]) {
                leaf = keccak256(abi.encodePacked(leaf, proof[i]));
            } else {
                leaf = keccak256(abi.encodePacked(proof[i], leaf));
            }
        }
        return leaf == root;
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newRecipient;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
