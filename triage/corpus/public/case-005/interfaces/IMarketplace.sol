// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketplace {
    struct Order {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 expiry;
    }

    event OrderFilled(
        bytes32 indexed orderId,
        address indexed seller,
        address indexed buyer,
        address nftContract,
        uint256 tokenId,
        uint256 price
    );
    event OrderCancelled(bytes32 indexed orderId, address indexed seller);
    event RoyaltyPaid(address indexed receiver, uint256 amount);
    event FeeUpdated(uint256 newFeeBps);

    error OrderFilled_();
    error OrderCancelled_();
    error OrderExpired();
    error WrongPrice();
    error NotSeller();
    error BadSignature();
    error FeeTooHigh();

    function fillOrder(Order calldata order, bytes calldata sig) external payable;
    function cancelOrder(Order calldata order) external;
    function setFee(uint256 newFeeBps) external;
    function orderId(Order calldata order) external pure returns (bytes32);
}
