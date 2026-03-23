// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AssetRegistry {
    address public admin;
    mapping(address => bool) public supported;
    address[] public assets;

    event AssetAdded(address indexed asset);
    event AssetRemoved(address indexed asset);

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    function addAsset(address asset) external onlyAdmin {
        require(!supported[asset], "already supported");
        supported[asset] = true;
        assets.push(asset);
        emit AssetAdded(asset);
    }

    function removeAsset(address asset) external onlyAdmin {
        require(supported[asset], "not supported");
        supported[asset] = false;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                assets[i] = assets[assets.length - 1];
                assets.pop();
                break;
            }
        }
        emit AssetRemoved(asset);
    }

    function isSupported(address asset) external view returns (bool) {
        return supported[asset];
    }

    function getAssets() external view returns (address[] memory) {
        return assets;
    }
}
