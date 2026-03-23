// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NFTMinter is ERC721, Ownable {
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MAX_PER_WALLET = 5;
    uint256 public constant PRICE = 0.05 ether;

    uint256 public totalMinted;
    bytes32 public whitelistRoot;
    bool public publicSaleOpen;
    bool public whitelistSaleOpen;

    mapping(address => uint256) public mintedCount;

    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {}

    function setWhitelistRoot(bytes32 root) external onlyOwner {
        whitelistRoot = root;
    }

    function setPublicSaleOpen(bool open) external onlyOwner {
        publicSaleOpen = open;
    }

    function setWhitelistSaleOpen(bool open) external onlyOwner {
        whitelistSaleOpen = open;
    }

    function whitelistMint(uint256 amount, bytes32[] calldata proof) external payable {
        require(whitelistSaleOpen, "whitelist sale closed");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, whitelistRoot, leaf), "not whitelisted");
        _mintChecked(amount);
    }

    function publicMint(uint256 amount) external payable {
        require(publicSaleOpen, "public sale closed");
        _mintChecked(amount);
    }

    function _mintChecked(uint256 amount) internal {
        require(amount > 0, "zero amount");
        require(totalMinted + amount <= MAX_SUPPLY, "exceeds supply");
        require(mintedCount[msg.sender] + amount <= MAX_PER_WALLET, "exceeds wallet cap");
        require(msg.value == PRICE * amount, "wrong payment");
        mintedCount[msg.sender] += amount;
        uint256 startId = totalMinted;
        totalMinted += amount;
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, startId + i);
        }
    }

    function withdraw() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        require(ok, "failed");
    }
}
