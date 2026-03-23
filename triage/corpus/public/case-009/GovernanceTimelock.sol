// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IGovernanceTimelock.sol";

contract GovernanceTimelock is IGovernanceTimelock {
    address public governance;
    address public guardian;
    uint256 public minDelay;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 7 days;

    mapping(bytes32 => uint256) public queuedAt;
    mapping(bytes32 => bool) public executed;

    uint256 public executionCount;
    uint256 public cancellationCount;

    event Queued(bytes32 indexed txHash, address target, uint256 value, bytes data, uint256 eta);
    event Executed(bytes32 indexed txHash, address target, uint256 value, bytes data);
    event Cancelled(bytes32 indexed txHash);
    event GovernanceUpdated(address indexed oldGov, address indexed newGov);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event MinDelayUpdated(uint256 oldDelay, uint256 newDelay);

    error NotGovernance();
    error NotGuardian();
    error DelayTooShort(uint256 provided, uint256 minimum);
    error DelayTooLong(uint256 provided, uint256 maximum);
    error AlreadyQueued(bytes32 txHash);
    error NotQueued(bytes32 txHash);
    error TooEarly(uint256 eta, uint256 current);
    error Expired(uint256 eta, uint256 current);
    error AlreadyExecuted(bytes32 txHash);
    error ExecutionFailed(bytes32 txHash);

    modifier onlyGovernance() {
        if (msg.sender != governance) revert NotGovernance();
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian && msg.sender != governance) revert NotGuardian();
        _;
    }

    constructor(address _governance, address _guardian, uint256 _minDelay) {
        require(_minDelay <= MAX_DELAY, "delay too long");
        governance = _governance;
        guardian = _guardian;
        minDelay = _minDelay;
    }

    function queue(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 delay
    ) external onlyGovernance returns (bytes32 txHash) {
        if (delay < minDelay) revert DelayTooShort(delay, minDelay);
        if (delay > MAX_DELAY) revert DelayTooLong(delay, MAX_DELAY);
        uint256 eta = block.timestamp + delay;
        txHash = keccak256(abi.encode(target, value, data, eta));
        if (queuedAt[txHash] != 0) revert AlreadyQueued(txHash);
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
        if (eta == 0) revert NotQueued(txHash);
        if (executed[txHash]) revert AlreadyExecuted(txHash);
        if (block.timestamp < eta) revert TooEarly(eta, block.timestamp);
        if (block.timestamp > eta + GRACE_PERIOD) revert Expired(eta, block.timestamp);
        executed[txHash] = true;
        delete queuedAt[txHash];
        executionCount += 1;
        (bool ok,) = target.call{value: value}(data);
        if (!ok) revert ExecutionFailed(txHash);
        emit Executed(txHash, target, value, data);
    }

    function executeMulti(
        bytes32[] calldata txHashes,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external onlyGovernance {
        require(txHashes.length == targets.length, "length mismatch");
        require(targets.length == values.length, "length mismatch");
        require(values.length == datas.length, "length mismatch");
        for (uint256 i = 0; i < txHashes.length; i++) {
            uint256 eta = queuedAt[txHashes[i]];
            if (eta == 0) revert NotQueued(txHashes[i]);
            if (executed[txHashes[i]]) revert AlreadyExecuted(txHashes[i]);
            if (block.timestamp < eta) revert TooEarly(eta, block.timestamp);
            if (block.timestamp > eta + GRACE_PERIOD) revert Expired(eta, block.timestamp);
            executed[txHashes[i]] = true;
            delete queuedAt[txHashes[i]];
            executionCount += 1;
            (bool ok,) = targets[i].call{value: values[i]}(datas[i]);
            if (!ok) revert ExecutionFailed(txHashes[i]);
            emit Executed(txHashes[i], targets[i], values[i], datas[i]);
        }
    }

    function cancel(bytes32 txHash) external onlyGuardian {
        if (queuedAt[txHash] == 0) revert NotQueued(txHash);
        delete queuedAt[txHash];
        cancellationCount += 1;
        emit Cancelled(txHash);
    }

    function updateGovernance(address newGov) external onlyGovernance {
        require(newGov != address(0), "zero address");
        emit GovernanceUpdated(governance, newGov);
        governance = newGov;
    }

    function updateGuardian(address newGuardian) external onlyGovernance {
        emit GuardianUpdated(guardian, newGuardian);
        guardian = newGuardian;
    }

    function updateMinDelay(uint256 newDelay) external onlyGovernance {
        require(newDelay <= MAX_DELAY, "delay too long");
        emit MinDelayUpdated(minDelay, newDelay);
        minDelay = newDelay;
    }

    function isQueued(bytes32 txHash) external view returns (bool) {
        return queuedAt[txHash] != 0 && !executed[txHash];
    }

    receive() external payable {}
}
