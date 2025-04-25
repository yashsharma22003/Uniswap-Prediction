// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MarketFactory} from "../src/MarketFactory.sol";
import {CryptoMarketPool} from "../src/CryptoMarketPool.sol";
import {StatementMarketPool} from "../src/StatementMarketPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarketFactoryTest is Test {
    MarketFactory private marketFactory;
    address private deployer;

    // Mock addresses for testing
    address private ftsOracleAdapter =
        address(0x0034567890abcDeF1234567890AbcDEf12345678);
    address private fdcOracleAdapter =
        address(0x0034567890abcDeF1234567890AbcDEf12345678);
    address private rewardToken =
        address(0x0034567890abcDeF1234567890AbcDEf12345678);
    uint256 private validResolveTimestamp;
    uint256 private validParticipationDeadline;
    uint256 private validMinStake = 1 ether;
    uint256 private validPredictAmount = 1000;
    string private cryptoTargeted = "BTC";
    uint256 private highBetTokenMaxSupply = 1000000;
    uint256 private lowBetTokenMaxSupply = 1000000;
    address private protocolTreasury =
        address(0x0034567890abcDeF1234567890AbcDEf12345678);

    function setUp() public {
        deployer = address(this);
        marketFactory = new MarketFactory();

        // Set valid timestamps
        validResolveTimestamp = block.timestamp + 1 weeks; // 1 week in the future
        validParticipationDeadline = block.timestamp + 3 days; // 3 days before resolve timestamp
    }


    function testInvalidResolveTimestamp() public {
        // Try deploying with an invalid resolve timestamp (in the past)
        vm.expectRevert("Resolve timestamp must be in the future");
        marketFactory.deployCryptoCampaign{value: 1 ether}(
            validPredictAmount,
            cryptoTargeted,
            ftsOracleAdapter,
            block.timestamp - 1, // Invalid resolve timestamp in the past
            validParticipationDeadline,
            validMinStake,
            rewardToken,
            highBetTokenMaxSupply,
            lowBetTokenMaxSupply,
            protocolTreasury
        );
    }

    function testInvalidParticipationDeadline() public {
        // Try deploying with an invalid participation deadline (after resolve timestamp)
        vm.expectRevert(
            "Participation deadline must be before resolve timestamp"
        );
        marketFactory.deployCryptoCampaign{value: 1 ether}(
            validPredictAmount,
            cryptoTargeted,
            ftsOracleAdapter,
            validResolveTimestamp,
            validResolveTimestamp + 1 days, // Invalid participation deadline after resolve timestamp
            validMinStake,
            rewardToken,
            highBetTokenMaxSupply,
            lowBetTokenMaxSupply,
            protocolTreasury
        );
    }
}
