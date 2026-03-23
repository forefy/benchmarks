// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// NFT marketplace with permit-based gasless listings.
// Sellers sign off-chain orders; buyers fill them by presenting the signature.
contract NFTMarketplace {
    struct Order {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 expiry;
    }

    mapping(bytes32 => bool) public filled;
    mapping(bytes32 => bool) public cancelled;

    uint256 public feeBps = 250;
    address public feeRecipient;
    address public owner;

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
        owner = msg.sender;
    }

    function fillOrder(Order calldata order, bytes calldata sig) external payable {
        bytes32 orderId = keccak256(abi.encode(order));
        require(!filled[orderId], "filled");
        require(!cancelled[orderId], "cancelled");
        require(block.timestamp < order.expiry, "expired");
        require(msg.value == order.price, "wrong price");

        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", orderId));
        address signer = _recover(digest, sig);
        require(signer == order.seller, "bad sig");

        filled[orderId] = true;

        uint256 fee = (order.price * feeBps) / 10000;
        payable(feeRecipient).transfer(fee);
        payable(order.seller).transfer(order.price - fee);

        IERC721(order.nftContract).transferFrom(order.seller, msg.sender, order.tokenId);
    }

    function cancelOrder(Order calldata order) external {
        require(msg.sender == order.seller, "not seller");
        bytes32 orderId = keccak256(abi.encode(order));
        cancelled[orderId] = true;
    }

    function setFee(uint256 newFeeBps) external {
        require(msg.sender == owner, "not owner");
        feeBps = newFeeBps;
    }

    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(digest, v, r, s);
    }
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}
