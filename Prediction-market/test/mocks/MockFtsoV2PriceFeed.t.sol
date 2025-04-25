// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/Mock/MockFtsoV2PriceFeed.sol";

contract MockFtsoV2PriceFeedTest is Test {
    MockFtsoV2PriceFeed public mockFeed;

    function setUp() public {
        mockFeed = new MockFtsoV2PriceFeed("C2FLR");
    }

    function testInitialValues() public view{
        (uint256 price, int8 decimals, uint64 timestamp) = mockFeed
            .getPriceFeed("C2FLR");

        assertEq(price, 2000 * 1e18);
        assertEq(decimals, 18);
        assertApproxEqAbs(timestamp, block.timestamp, 2); // Accept 2s diff
    }

    function testSetPrice() public {
        mockFeed.setPrice(1234 * 1e18, 8, 1680000000);

        (uint256 price, int8 decimals, uint64 timestamp) = mockFeed
            .getPriceFeed("C2FLR");

        assertEq(price, 1234 * 1e18);
        assertEq(decimals, 8);
        assertEq(timestamp, 1680000000);
    }

    function testSetTimestamp() public {
        mockFeed.setTimestamp(1700000000);
        (, , uint64 timestamp) = mockFeed.getPriceFeed("C2FLR");

        assertEq(timestamp, 1700000000);
    }

    function testSetSymbol() public {
        mockFeed.setSymbol("WC2FLR");
        vm.expectRevert("Mock: Symbol not supported");
        mockFeed.getPriceFeed("C2FLR");

        (uint256 price, int8 decimals, uint64 timestamp) = mockFeed
            .getPriceFeed("WC2FLR");
        assertEq(price, 2000 * 1e18);
        assertEq(decimals, 18);
        assertEq(timestamp, mockFeed.mockTimestamp());
    }

    function testRevertOnWrongSymbol() public {
        vm.expectRevert("Mock: Symbol not supported");
        mockFeed.getPriceFeed("UNKNOWN");
    }
}
