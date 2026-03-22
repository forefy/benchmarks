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

    function bid(uint256 auctionId) external payable {
        Auction storage a = auctions[auctionId];
        require(block.timestamp < a.endTime, 'ended');
        require(msg.value > a.highestBid, 'too low');
        pendingReturns[a.highestBidder] += a.highestBid;
        a.highestBidder = msg.sender;
        a.highestBid = msg.value;
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function settle(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.endTime, 'not ended');
        require(!a.settled, 'settled');
        a.settled = true;
    }
}