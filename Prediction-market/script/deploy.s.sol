// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MarketFactory} from "../src/MarketFactory.sol";
import {CryptoMarketPool} from "../src/CryptoMarketPool.sol";
import {FtsoV2PriceFeed} from "../src/FtsoV2PriceFeed.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract Deploy is Script {
    string[] crypto = ["FLR", "SGB", "BTC", "XRP", "LTC", "XLM", "DOGE", "ADA", "ALGO", "ETH"];

    bytes21[] feedIds = [
        bytes21(0x01464c522f55534400000000000000000000000000), // FLR/USD
        bytes21(0x015347422f55534400000000000000000000000000), // SGB/USD
        bytes21(0x014254432f55534400000000000000000000000000), // BTC/USD
        bytes21(0x015852502f55534400000000000000000000000000), // XRP/USD
        bytes21(0x014c54432f55534400000000000000000000000000), // LTC/USD
        bytes21(0x01584c4d2f55534400000000000000000000000000), // XLM/USD
        bytes21(0x01444f47452f555344000000000000000000000000), // DOGE/USD
        bytes21(0x014144412f55534400000000000000000000000000), // ADA/USD
        bytes21(0x01414c474f2f555344000000000000000000000000), // ALGO/USD
        bytes21(0x014554482f55534400000000000000000000000000)  // ETH/USD
    ];

    function run() public {
        vm.startBroadcast();

        FtsoV2PriceFeed ftsoV2 = new FtsoV2PriceFeed(crypto, feedIds);
        console.log("FtsoV2PriceFeed deployed at:", address(ftsoV2));

        MarketFactory marketFactory = new MarketFactory();
        console.log("MarketFactory deployed at:", address(marketFactory));

        vm.stopBroadcast();
    }
}
