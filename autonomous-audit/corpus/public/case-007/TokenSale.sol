// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
}

contract TokenSale {
    IERC20 public paymentToken;
    IERC20 public saleToken;
    address public admin;

    uint256 public price = 1e18;
    uint256 public sold;
    uint256 public cap = 1_000_000e18;
    bool public saleOpen;

    mapping(address => uint256) public purchased;

    constructor(address _payment, address _sale) {
        paymentToken = IERC20(_payment);
        saleToken = IERC20(_sale);
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    function openSale() external onlyAdmin {
        saleOpen = true;
    }

    function closeSale() external onlyAdmin {
        saleOpen = false;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function setCap(uint256 _cap) external onlyAdmin {
        cap = _cap;
    }

    function buy(uint256 tokenAmount) external {
        require(saleOpen, "sale closed");
        require(sold + tokenAmount <= cap, "cap reached");

        uint256 cost = (tokenAmount * price) / 1e18;
        paymentToken.transferFrom(msg.sender, address(this), cost);
        sold += tokenAmount;
        purchased[msg.sender] += tokenAmount;
        saleToken.transfer(msg.sender, tokenAmount);
    }

    function withdrawPayments(address to) external onlyAdmin {
        uint256 balance = paymentToken.balanceOf(address(this));
        paymentToken.transfer(to, balance);
    }

    function transferAdmin(address newAdmin) external {
        admin = newAdmin;
    }
}
