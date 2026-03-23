// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTAuction {
    function createAuction(uint256 auctionId, uint256 duration) external;
    function bid(uint256 auctionId) external payable;
    function withdraw() external;
    function settle(uint256 auctionId) external;
}
