// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;
    uint256 public nonce;

    event Submitted(uint256 indexed txId);
    event Approved(uint256 indexed txId, address indexed owner);
    event Executed(uint256 indexed txId);
    event Revoked(uint256 indexed txId, address indexed owner);

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "no owners");
        require(_threshold > 0 && _threshold <= _owners.length, "invalid threshold");
        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0) && !isOwner[o], "invalid owner");
            isOwner[o] = true;
            owners.push(o);
        }
        threshold = _threshold;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    function submit(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        txId = transactions.length;
        transactions.push(Transaction(to, value, data, false, 0));
        emit Submitted(txId);
    }

    function approve(uint256 txId) external onlyOwner {
        require(txId < transactions.length, "invalid tx");
        require(!transactions[txId].executed, "already executed");
        require(!approved[txId][msg.sender], "already approved");
        approved[txId][msg.sender] = true;
        transactions[txId].approvalCount += 1;
        emit Approved(txId, msg.sender);
    }

    function revoke(uint256 txId) external onlyOwner {
        require(!transactions[txId].executed, "already executed");
        require(approved[txId][msg.sender], "not approved");
        approved[txId][msg.sender] = false;
        transactions[txId].approvalCount -= 1;
        emit Revoked(txId, msg.sender);
    }

    function execute(uint256 txId) external onlyOwner {
        Transaction storage t = transactions[txId];
        require(!t.executed, "already executed");
        require(t.approvalCount >= threshold, "below threshold");
        t.executed = true;
        (bool ok,) = t.to.call{value: t.value}(t.data);
        require(ok, "call failed");
        emit Executed(txId);
    }

    receive() external payable {}
}
