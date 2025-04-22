// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract MockFtsoV2PriceFeed  {
    uint256 public mockPrice;
    int8 public mockDecimals;
    uint64 public mockTimestamp;
    string public supportedSymbol;

    constructor(string memory _symbol) {
        supportedSymbol = _symbol;
        // Set some default values
        mockPrice = 2000 * (10**18); // Example price
        mockDecimals = 18;
        mockTimestamp = uint64(block.timestamp);
    }

    function setPrice(uint256 _price, int8 _decimals, uint64 _timestamp) external {
        mockPrice = _price;
        mockDecimals = _decimals;
        mockTimestamp = _timestamp;
    }

    function setTimestamp(uint64 _timestamp) external {
        mockTimestamp = _timestamp;
    }

    function setSymbol(string memory _symbol) external {
        supportedSymbol = _symbol;
    }

    function getPriceFeed(string memory _symbol)
        external
        view
        returns (uint256 _price, int8 _decimals, uint64 _timestamp)
    {
        require(
            keccak256(abi.encodePacked(_symbol)) == keccak256(abi.encodePacked(supportedSymbol)),
            "Mock: Symbol not supported"
        );
        return (mockPrice, mockDecimals, mockTimestamp);
    }
}