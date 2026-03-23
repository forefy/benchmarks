// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GovernanceTimelock {
    address public governance;
    uint256 public minDelay;
    uint256 public constant MAX_DELAY = 30 days;

    mapping(bytes32 => uint256) public queuedAt;

    event Queued(bytes32 indexed txHash, address target, uint256 value, bytes data, uint256 eta);
    event Executed(bytes32 indexed txHash);
    event Cancelled(bytes32 indexed txHash);

    constructor(address _governance, uint256 _minDelay) {
        require(_minDelay <= MAX_DELAY, "delay too long");
        governance = _governance;
        minDelay = _minDelay;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "not governance");
        _;
    }

    function queue(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 delay
    ) external onlyGovernance returns (bytes32 txHash) {
        require(delay >= minDelay, "delay too short");
        require(delay <= MAX_DELAY, "delay too long");
        uint256 eta = block.timestamp + delay;
        txHash = keccak256(abi.encode(target, value, data, eta));
        require(queuedAt[txHash] == 0, "already queued");
        queuedAt[txHash] = eta;
        emit Queued(txHash, target, value, data, eta);
    }

    function execute(
        bytes32 txHash,
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyGovernance {
        uint256 eta = queuedAt[txHash];
        require(eta != 0, "not queued");
        require(block.timestamp >= eta, "too early");
        require(block.timestamp <= eta + 7 days, "expired");
        delete queuedAt[txHash];
        (bool ok,) = target.call{value: value}(data);
        require(ok, "execution failed");
        emit Executed(txHash);
    }

    function cancel(bytes32 txHash) external onlyGovernance {
        require(queuedAt[txHash] != 0, "not queued");
        delete queuedAt[txHash];
        emit Cancelled(txHash);
    }

    receive() external payable {}
}
