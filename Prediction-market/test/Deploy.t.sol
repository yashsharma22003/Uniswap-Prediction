// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
// Assuming these imports are correctly configured in your foundry.toml
import {Deploy} from "../script/Deploy.s.sol"; // Keep if needed, though not used in setUp directly
import {FtsoV2PriceFeed} from "../src/FtsoV2PriceFeed.sol"; // Import the contract under test
import {MarketFactory} from "../src/MarketFactory.sol"; // Keep if MarketFactory test is still needed

contract DeployTest is Test {
    FtsoV2PriceFeed public ftso; // Renamed variable for clarity
    MarketFactory public marketFactory; // Keep if needed

    // These arrays are used to provide data to the FtsoV2PriceFeed constructor
    string[] internal feedNames; // Use internal/private as they are not public state variables in the contract
    bytes21[] internal feedIds; // Use internal/private as they are not public state variables in the contract

    function setUp() public {
        // Initialize the data arrays used for deployment
        feedNames = new string[](10);
        feedIds = new bytes21[](10);

        feedNames[0] = "FLR";
        feedNames[1] = "SGB";
        feedNames[2] = "BTC";
        feedNames[3] = "XRP";
        feedNames[4] = "LTC";
        feedNames[5] = "XLM";
        feedNames[6] = "DOGE";
        feedNames[7] = "ADA";
        feedNames[8] = "ALGO";
        feedNames[9] = "ETH";

        feedIds[0] = bytes21(0x01464c522f55534400000000000000000000000000); // FLR/USD
        feedIds[1] = bytes21(0x015347422f55534400000000000000000000000000); // SGB/USD
        feedIds[2] = bytes21(0x014254432f55534400000000000000000000000000); // BTC/USD
        feedIds[3] = bytes21(0x015852502f55534400000000000000000000000000); // XRP/USD
        feedIds[4] = bytes21(0x014c54432f55534400000000000000000000000000); // LTC/USD
        feedIds[5] = bytes21(0x01584c4d2f55534400000000000000000000000000); // XLM/USD
        feedIds[6] = bytes21(0x01444f47452f555344000000000000000000000000); // DOGE/USD
        feedIds[7] = bytes21(0x014144412f55534400000000000000000000000000); // ADA/USD
        feedIds[8] = bytes21(0x01414c474f2f555344000000000000000000000000); // ALGO/USD
        feedIds[9] = bytes21(0x014554482f55534400000000000000000000000000); // ETH/USD

        // Deploy the contract under test using the initialized arrays
        ftso = new FtsoV2PriceFeed(feedNames, feedIds);

        // Deploy the MarketFactory (if still needed in this test suite)
        marketFactory = new MarketFactory();
    }

    // --- Tests for FtsoV2PriceFeed Deployment and Constructor ---

    function testFtsoDeployment() public view {
        // Check if ftso contract address is not zero
        assert(address(ftso) != address(0));

        // In the new FtsoV2PriceFeed, feedIds is a public mapping.
        // Solidity automatically creates a getter function for public mappings.
        // We can use this getter to check if the constructor correctly populated the mapping.
        // We check the mapping by providing a feed name (string) and expecting the corresponding bytes21 ID.

        // Check a few key-value pairs from the mapping
        assertEq(
            ftso.feedIds("FLR"),
            bytes21(0x01464c522f55534400000000000000000000000000),
            "FLR feedId mismatch"
        );
        assertEq(
            ftso.feedIds("SGB"),
            bytes21(0x015347422f55534400000000000000000000000000),
            "SGB feedId mismatch"
        );
        assertEq(
            ftso.feedIds("BTC"),
            bytes21(0x014254432f55534400000000000000000000000000),
            "BTC feedId mismatch"
        );
        assertEq(
            ftso.feedIds("ETH"),
            bytes21(0x014554482f55534400000000000000000000000000),
            "ETH feedId mismatch"
        );
        // Add more checks for other feed names if desired
    }

    // Optional: Add a test to check if querying a non-existent key returns the default value (bytes21 zero)
    function testFtsoDeployment_NonExistentFeed() public view {
        bytes21 defaultBytes21 = bytes21(
            0x000000000000000000000000000000000000000000
        );
        assertEq(
            ftso.feedIds("NONEXISTENT"),
            defaultBytes21,
            "Non-existent feedId should be zero"
        );
    }
}
