//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestFtsoV2Interface } from "lib/flare-periphery-contracts/coston2/TestFtsoV2Interface.sol";
import { ContractRegistry } from "lib/flare-periphery-contracts/coston2/ContractRegistry.sol";

contract FtsoV2PriceFeed {

    TestFtsoV2Interface internal ftsoV2;

    mapping (string => bytes21) public feedIds;

    constructor (string[] memory _feedNames, bytes21[] memory _feedIds) {
        uint256 length = _feedIds.length;
        for(uint256 i = 0; i < length; i++) { 
            feedIds[_feedNames[i]] = _feedIds[i];
        }
    }

    function getPriceFeed(string memory _feedName) public 
     returns (
            uint256 _feedValue,
            int8 _decimal,
            uint64 _timestamp
        )
         {
        ftsoV2 = ContractRegistry.getTestFtsoV2();
        return ftsoV2.getFeedById(feedIds[_feedName]);
    }

}