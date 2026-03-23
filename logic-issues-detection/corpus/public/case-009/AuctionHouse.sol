// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/INFTAuction.sol";

contract AuctionHouse is INFTAuction {
    struct Auction {
        address creator;
        address highestBidder;
        uint256 highestBid;
        uint256 endTime;
        uint256 reservePrice;
        uint256 royaltyBps;
        address royaltyRecipient;
        bool settled;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingReturns;
    mapping(uint256 => address[]) private _bidders;
    mapping(uint256 => uint256[]) private _bidAmounts;

    uint256 public constant MIN_BID_INCREMENT_BPS = 500;
    uint256 public constant MAX_ROYALTY_BPS = 1000;
    uint256 public constant BASIS_POINTS = 10_000;

    address public owner;
    bool private _locked;

    event AuctionCreated(uint256 indexed auctionId, address indexed creator, uint256 reservePrice, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionSettled(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    error Unauthorized();
    error Reentrant();
    error AuctionExists();
    error AuctionEnded();
    error AuctionNotEnded();
    error AlreadySettled();
    error BelowReserve();
    error BelowMinIncrement();
    error InvalidRoyalty();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function createAuction(uint256 auctionId, uint256 duration) external override {
        createAuctionWithParams(auctionId, duration, 0, 0, address(0));
    }

    function createAuctionWithParams(
        uint256 auctionId,
        uint256 duration,
        uint256 reservePrice,
        uint256 royaltyBps,
        address royaltyRecipient
    ) public {
        if (auctions[auctionId].endTime != 0) revert AuctionExists();
        if (royaltyBps > MAX_ROYALTY_BPS) revert InvalidRoyalty();
        auctions[auctionId] = Auction({
            creator: msg.sender,
            highestBidder: address(0),
            highestBid: 0,
            endTime: block.timestamp + duration,
            reservePrice: reservePrice,
            royaltyBps: royaltyBps,
            royaltyRecipient: royaltyRecipient,
            settled: false
        });
        emit AuctionCreated(auctionId, msg.sender, reservePrice, block.timestamp + duration);
    }

    function bid(uint256 auctionId) external payable override nonReentrant {
        Auction storage a = auctions[auctionId];
        if (block.timestamp >= a.endTime) revert AuctionEnded();
        if (a.highestBid == 0) {
            if (msg.value < a.reservePrice) revert BelowReserve();
        } else {
            uint256 minBid = a.highestBid + (a.highestBid * MIN_BID_INCREMENT_BPS / BASIS_POINTS);
            if (msg.value < minBid) revert BelowMinIncrement();
        }
        pendingReturns[a.highestBidder] += a.highestBid;
        _bidders[auctionId].push(msg.sender);
        _bidAmounts[auctionId].push(msg.value);
        a.highestBidder = msg.sender;
        a.highestBid = msg.value;
        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function withdraw() external override nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "nothing to withdraw");
        pendingReturns[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function settle(uint256 auctionId) external override nonReentrant {
        Auction storage a = auctions[auctionId];
        if (block.timestamp < a.endTime) revert AuctionNotEnded();
        if (a.settled) revert AlreadySettled();
        a.settled = true;
        if (a.highestBidder == address(0)) {
            emit AuctionSettled(auctionId, address(0), 0);
            return;
        }
        if (a.royaltyRecipient != address(0) && a.royaltyBps > 0) {
            uint256 royalty = a.highestBid * a.royaltyBps / BASIS_POINTS;
            uint256 proceeds = a.highestBid - royalty;
            (bool rok,) = a.royaltyRecipient.call{value: royalty}("");
            if (!rok) revert TransferFailed();
            (bool cok,) = a.creator.call{value: proceeds}("");
            if (!cok) revert TransferFailed();
        } else {
            (bool ok,) = a.creator.call{value: a.highestBid}("");
            if (!ok) revert TransferFailed();
        }
        emit AuctionSettled(auctionId, a.highestBidder, a.highestBid);
    }

    function getBidHistory(uint256 auctionId) external view returns (address[] memory bidders, uint256[] memory amounts) {
        bidders = _bidders[auctionId];
        amounts = _bidAmounts[auctionId];
    }

    function auctionStatus(uint256 auctionId) external view returns (
        bool active,
        bool settled,
        address highestBidder,
        uint256 highestBid,
        uint256 timeRemaining
    ) {
        Auction storage a = auctions[auctionId];
        active = block.timestamp < a.endTime && !a.settled;
        settled = a.settled;
        highestBidder = a.highestBidder;
        highestBid = a.highestBid;
        timeRemaining = block.timestamp < a.endTime ? a.endTime - block.timestamp : 0;
    }
}
