// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DutchAuction {
    IERC20 public token;
    address public seller;

    uint256 public startPrice;
    uint256 public reservePrice;
    uint256 public startTime;
    uint256 public duration;
    uint256 public tokensForSale;
    uint256 public tokensSold;

    constructor(
        address _token,
        uint256 _startPrice,
        uint256 _reservePrice,
        uint256 _duration,
        uint256 _tokensForSale
    ) {
        token = IERC20(_token);
        seller = msg.sender;
        startPrice = _startPrice;
        reservePrice = _reservePrice;
        startTime = block.timestamp;
        duration = _duration;
        tokensForSale = _tokensForSale;
    }

    function currentPrice() public view returns (uint256) {
        if (block.timestamp >= startTime + duration) return reservePrice;
        uint256 elapsed = block.timestamp - startTime;
        uint256 priceDrop = ((startPrice - reservePrice) * elapsed) / duration;
        return startPrice - priceDrop;
    }

    function buy(uint256 tokenAmount) external payable {
        require(tokensSold + tokenAmount <= tokensForSale, "sold out");
        uint256 price = currentPrice();
        uint256 cost = (tokenAmount * price) / 1e18;
        require(msg.value >= cost, "underpaid");
        uint256 excess = msg.value - cost;
        if (excess > 0) {
            (bool ok,) = msg.sender.call{value: excess}("");
            require(ok, "refund failed");
        }
        tokensSold += tokenAmount;
        token.transfer(msg.sender, tokenAmount);
    }

    function withdrawProceeds() external {
        require(msg.sender == seller, "not seller");
        (bool ok,) = seller.call{value: address(this).balance}("");
        require(ok, "failed");
    }

    receive() external payable {}
}
