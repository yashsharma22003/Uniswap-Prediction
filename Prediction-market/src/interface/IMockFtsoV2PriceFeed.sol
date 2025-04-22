// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMockFtsoV2PriceFeed {
    // function price() external view returns (uint256);
    // function decimals() external view returns (int8);
    // function timestamp() external view returns (uint64);
    // function returnStale() external view returns (bool);

    function setPrice(uint256 _price, int8 _decimals, uint64 _timestamp) external;
    function setStaleTimestamp(uint64 _timestamp) external;

    function getPriceFeed(string memory _symbol) external view returns (
        uint256 _price,
        int8 _decimals,
        uint64 _timestamp
    );
}
