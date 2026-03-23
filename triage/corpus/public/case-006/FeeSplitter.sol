// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IFeeSplitter.sol";

contract FeeSplitter is IFeeSplitter {
    address public partyA;
    address public partyB;
    uint256 public shareA;
    uint256 public shareB;

    address public admin;

    uint256 public totalReceived;
    uint256 public totalDistributed;
    uint256 public splitCount;

    struct SplitRecord {
        uint256 amount;
        uint256 amountA;
        uint256 amountB;
        uint256 timestamp;
    }

    SplitRecord[] public history;

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor(address _partyA, address _partyB, uint256 _shareA, uint256 _shareB) {
        if (_shareA + _shareB != 100) revert SharesMustSum100();
        if (_partyA == address(0) || _partyB == address(0)) revert ZeroAddress();
        partyA = _partyA;
        partyB = _partyB;
        shareA = _shareA;
        shareB = _shareB;
        admin = msg.sender;
    }

    receive() external payable {
        totalReceived += msg.value;
        emit FeeReceived(msg.sender, msg.value);
    }

    function split() external {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NothingToSplit();
        uint256 amountA = (balance * shareA) / 100;
        uint256 amountB = balance - amountA;
        totalDistributed += balance;
        splitCount += 1;
        history.push(SplitRecord({
            amount: balance,
            amountA: amountA,
            amountB: amountB,
            timestamp: block.timestamp
        }));
        payable(partyA).transfer(amountA);
        payable(partyB).transfer(amountB);
        emit FeeSplit(partyA, amountA, partyB, amountB);
    }

    function updateParty(bool isPartyA, address newParty) external onlyAdmin {
        if (newParty == address(0)) revert ZeroAddress();
        if (isPartyA) {
            emit PartyUpdated(true, partyA, newParty);
            partyA = newParty;
        } else {
            emit PartyUpdated(false, partyB, newParty);
            partyB = newParty;
        }
    }

    function updateShares(uint256 newShareA, uint256 newShareB) external onlyAdmin {
        if (newShareA + newShareB != 100) revert SharesMustSum100();
        shareA = newShareA;
        shareB = newShareB;
        emit SharesUpdated(newShareA, newShareB);
    }

    function pendingAmount(bool isPartyA) external view returns (uint256) {
        uint256 balance = address(this).balance;
        if (isPartyA) return (balance * shareA) / 100;
        return balance - (balance * shareA) / 100;
    }

    function historyLength() external view returns (uint256) {
        return history.length;
    }

    function getHistorySlice(uint256 from, uint256 to) external view returns (SplitRecord[] memory slice) {
        require(to <= history.length && from <= to, "invalid range");
        slice = new SplitRecord[](to - from);
        for (uint256 i = from; i < to; i++) {
            slice[i - from] = history[i];
        }
    }

    function stats() external view returns (
        uint256 _totalReceived,
        uint256 _totalDistributed,
        uint256 _splitCount,
        uint256 _pendingBalance
    ) {
        _totalReceived = totalReceived;
        _totalDistributed = totalDistributed;
        _splitCount = splitCount;
        _pendingBalance = address(this).balance;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "zero address");
        admin = newAdmin;
    }

    function rescueETH() external onlyAdmin {
        require(splitCount == 0, "already split");
        uint256 balance = address(this).balance;
        payable(admin).transfer(balance);
    }

    function parties() external view returns (address _partyA, address _partyB, uint256 _shareA, uint256 _shareB) {
        _partyA = partyA;
        _partyB = partyB;
        _shareA = shareA;
        _shareB = shareB;
    }

    function expectedShareOf(address party, uint256 hypotheticalBalance) external view returns (uint256) {
        if (party == partyA) return (hypotheticalBalance * shareA) / 100;
        if (party == partyB) return hypotheticalBalance - (hypotheticalBalance * shareA) / 100;
        return 0;
    }
}
