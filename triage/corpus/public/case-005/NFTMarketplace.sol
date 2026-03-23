// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IMarketplace.sol";
import "./SignatureLib.sol";

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IRoyaltyRegistry {
    function royaltyInfo(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

contract NFTMarketplace is IMarketplace {
    mapping(bytes32 => bool) public filled;
    mapping(bytes32 => bool) public cancelled;

    uint256 public feeBps;
    address public feeRecipient;
    address public owner;
    IRoyaltyRegistry public royaltyRegistry;

    uint256 public constant MAX_FEE_BPS = 1000;
    uint256 public totalVolumeETH;
    uint256 public totalFeesCollected;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _feeRecipient, uint256 _feeBps) {
        require(_feeBps <= MAX_FEE_BPS, "fee too high");
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;
        owner = msg.sender;
    }

    function fillOrder(Order calldata order, bytes calldata sig) external payable {
        bytes32 id = keccak256(abi.encode(order));
        require(!filled[id], "filled");
        require(!cancelled[id], "cancelled");
        require(block.timestamp < order.expiry, "expired");
        require(msg.value == order.price, "wrong price");

        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", id));
        address signer = _recover(digest, sig);
        require(signer == order.seller, "bad sig");

        filled[id] = true;
        totalVolumeETH += order.price;

        uint256 remaining = order.price;

        if (address(royaltyRegistry) != address(0)) {
            (address royaltyReceiver, uint256 royaltyAmount) = royaltyRegistry.royaltyInfo(
                order.nftContract,
                order.tokenId,
                order.price
            );
            if (royaltyAmount > 0 && royaltyReceiver != address(0) && royaltyAmount < remaining) {
                payable(royaltyReceiver).transfer(royaltyAmount);
                remaining -= royaltyAmount;
                emit RoyaltyPaid(royaltyReceiver, royaltyAmount);
            }
        }

        uint256 fee = (order.price * feeBps) / 10000;
        if (fee > 0 && fee < remaining) {
            payable(feeRecipient).transfer(fee);
            remaining -= fee;
            totalFeesCollected += fee;
        }

        payable(order.seller).transfer(remaining);
        IERC721(order.nftContract).transferFrom(order.seller, msg.sender, order.tokenId);
        emit OrderFilled(id, order.seller, msg.sender, order.nftContract, order.tokenId, order.price);
    }

    function cancelOrder(Order calldata order) external {
        require(msg.sender == order.seller, "not seller");
        bytes32 id = keccak256(abi.encode(order));
        cancelled[id] = true;
        emit OrderCancelled(id, msg.sender);
    }

    function setFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= MAX_FEE_BPS, "fee too high");
        feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "zero address");
        feeRecipient = newRecipient;
    }

    function setRoyaltyRegistry(address registry) external onlyOwner {
        royaltyRegistry = IRoyaltyRegistry(registry);
    }

    function orderId(Order calldata order) external pure returns (bytes32) {
        return keccak256(abi.encode(order));
    }

    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(digest, v, r, s);
    }
}
