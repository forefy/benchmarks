// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NFTAuction {
    struct Auction {
        address highestBidder;
        uint256 highestBid;
        uint256 endTime;
        bool settled;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingReturns;
    uint256 public constant MIN_BID_INCREMENT_BPS = 500;

    function createAuction(uint256 auctionId, uint256 duration) external {
        auctions[auctionId] = Auction(address(0), 0, block.timestamp + duration, false);
    }

    function bid(uint256 auctionId) external payable {
        Auction storage a = auctions[auctionId];
        require(block.timestamp < a.endTime, 'ended');
        uint256 minBid = a.highestBid + (a.highestBid * MIN_BID_INCREMENT_BPS / 10_000);
        require(msg.value >= minBid, 'below minimum increment');
        pendingReturns[a.highestBidder] += a.highestBid;
        a.highestBidder = msg.sender;
        a.highestBid = msg.value;
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, 'nothing');
        pendingReturns[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, 'failed');
    }

    function settle(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.endTime, 'not ended');
        require(!a.settled, 'settled');
        a.settled = true;
    }
}
