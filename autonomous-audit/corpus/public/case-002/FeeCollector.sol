// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ConditionalEscrow {
    struct Escrow {
        address payable depositor;
        address payable recipient;
        uint256 amount;
        uint256 releaseBlock;
        bool settled;
    }

    mapping(uint256 => Escrow) public escrows;
    uint256 public nextId;

    event Created(uint256 indexed id, address depositor, address recipient, uint256 releaseBlock);
    event Released(uint256 indexed id);
    event Refunded(uint256 indexed id);

    function create(address payable recipient, uint256 releaseBlock) external payable returns (uint256 id) {
        require(msg.value > 0, "no value");
        require(releaseBlock > block.number, "invalid block");
        id = nextId++;
        escrows[id] = Escrow(payable(msg.sender), recipient, msg.value, releaseBlock, false);
        emit Created(id, msg.sender, recipient, releaseBlock);
    }

    function release(uint256 id) external {
        Escrow storage e = escrows[id];
        require(!e.settled, "settled");
        require(block.number >= e.releaseBlock, "not ready");
        e.settled = true;
        e.recipient.transfer(e.amount);
        emit Released(id);
    }

    function refund(uint256 id) external {
        Escrow storage e = escrows[id];
        require(msg.sender == e.depositor, "not depositor");
        require(!e.settled, "settled");
        e.settled = true;
        e.depositor.transfer(e.amount);
        emit Refunded(id);
    }
}
