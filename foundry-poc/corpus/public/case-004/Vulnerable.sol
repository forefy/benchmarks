// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEpochManager {
    function currentEpoch() external view returns (uint256);
    function epochRewardRate(uint256 epoch) external view returns (uint256);
}

interface IRewardToken {
    function mint(address to, uint256 amount) external;
}

contract RewardDistributor {
    address public admin;
    mapping(bytes32 => bool) public claimed;
    IEpochManager public epochManager;
    IRewardToken public rewardToken;
    uint256 public totalDistributed;

    event RewardClaimed(address indexed recipient, uint256 amount);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event EpochManagerSet(address indexed epochManager);

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function setEpochManager(address _epochManager) external onlyAdmin {
        epochManager = IEpochManager(_epochManager);
        emit EpochManagerSet(_epochManager);
    }

    function setRewardToken(address _rewardToken) external onlyAdmin {
        rewardToken = IRewardToken(_rewardToken);
    }

    function claim(address recipient, uint256 amount, bytes calldata sig) external {
        bytes32 msgHash = keccak256(abi.encodePacked(recipient, amount));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        address signer = _recover(ethHash, sig);
        require(signer == admin, "bad sig");
        (bool ok,) = recipient.call{value: amount}("");
        require(ok, "transfer failed");
        totalDistributed += amount;
        if (address(rewardToken) != address(0)) {
            uint256 bonus = amount / 10;
            if (bonus > 0) {
                rewardToken.mint(recipient, bonus);
            }
        }
        emit RewardClaimed(recipient, amount);
    }

    function _recover(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(hash, v, r, s);
    }

    receive() external payable {}
}
