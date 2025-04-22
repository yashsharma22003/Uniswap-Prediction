// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol"; // Import Vm for cheatcodes like expectEmit

// Import Interfaces (adjust path if needed)
// Make sure these paths are correct for your project structure
import { IBetToken } from "../src/interface/IBetToken.sol";
import { IMarketPoolCrypto } from "../src/interface/IMarketPoolCrypto.sol";
import { IMockFtsoV2PriceFeed } from "../src/Interface/IMockFtsoV2PriceFeed.sol"; // Assuming IFtsoV2PriceFeed is the correct interface name

// Import Contracts (adjust path if needed)
import { CryptoMarketPool } from "../src/CryptoMarketPool.sol";
// Remove these if HighBetToken/LowBetToken are not defined directly in CryptoMarketPool.sol
// import { HighBetToken } from "../src/CryptoMarketPool.sol";
// import { LowBetToken } from "../src/CryptoMarketPool.sol";
// import { BaseBetToken } from "../src/BetTokens/BaseBetToken.sol"; // Make sure this path is correct

// --- Mock Price Feed Contract ---
contract MockFtsoV2PriceFeed is IMockFtsoV2PriceFeed {
    uint256 public price;
    int8 public decimals;
    uint64 public timestamp;
    // Removed returnStale flag as it wasn't used effectively; staleness is determined by the caller

    function setPrice(uint256 _price, int8 _decimals, uint64 _timestamp) external {
        price = _price;
        decimals = _decimals;
        timestamp = _timestamp;
    }

    // Keeping setStaleTimestamp for the specific stale test case
    function setStaleTimestamp(uint64 _timestamp) external {
        timestamp = _timestamp;
    }

    function getPriceFeed(string memory /*_symbol*/)
        external
        view
        returns (uint256 _price, int8 _decimals, uint64 _timestamp)
    {
        return (price, decimals, timestamp);
    }
}

// --- Test Contract ---
contract CryptoMarketPoolToken is Test {
    // Contracts
    CryptoMarketPool internal pool;
    MockFtsoV2PriceFeed internal mockPriceFeed;
    IBetToken internal highToken;
    IBetToken internal lowToken;

    // Users
    address internal deployer = address(0x1); // Arbitrary deployer
    address internal alice = address(0xA11CE); // User Alice
    address internal bob = address(0xB0B);     // User Bob
    address internal protocolTreasury = address(0x7EAE); // Treasury

    // Pool Parameters
    uint256 internal predictAmount = 2000 * (10**18); // e.g., predict if BTC > $2000
    string internal cryptoTargeted = "BTC"; // Ensure this matches what FtsoV2 might expect if using real one later
    uint256 internal resolveTimestamp;
    uint256 internal participationDeadline;
    uint256 internal minStake = 0.1 ether;
    uint256 internal highBetTokenMaxSupply = 1_000_000 ether;
    uint256 internal lowBetTokenMaxSupply = 1_000_000 ether;
    uint8 internal constant POOL_PRECISION = 18;
    int8 internal constant ORACLE_DECIMALS = 18; // Assume oracle also uses 18 decimals for simplicity

    function setUp() public {
        // Label addresses
        vm.label(deployer, "Deployer");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(protocolTreasury, "ProtocolTreasury");

        // Deploy Mock Price Feed
        mockPriceFeed = new MockFtsoV2PriceFeed();

        // Deploy the Pool Contract
        vm.startPrank(deployer);
        pool = new CryptoMarketPool();
        vm.stopPrank();

        // Set timestamps relative to current block time
        participationDeadline = block.timestamp + 1 days;
        resolveTimestamp = block.timestamp + 2 days;

        // Initialize the pool
        // Use expectEmit correctly, ignoring topic1 (address) but checking data (maxSupply)
        // vm.expectEmit(false, true, true, true);
        emit IMarketPoolCrypto.HighBetTokenDeployed(address(0), highBetTokenMaxSupply);
        // vm.expectEmit(false, true, true, true);
        emit IMarketPoolCrypto.LowBetTokenDeployed(address(0), lowBetTokenMaxSupply);

        pool.initialize(
            predictAmount,
            cryptoTargeted,
            address(mockPriceFeed),
            resolveTimestamp,
            participationDeadline,
            minStake,
            highBetTokenMaxSupply,
            lowBetTokenMaxSupply,
            protocolTreasury
        );

        // Get token addresses
        highToken = IBetToken(pool.highBetToken());
        lowToken = IBetToken(pool.lowBetToken());

        // Fund users
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    // --- Test Initialization ---
    // (No changes needed here)
    function test_Initialization() public {
        assertTrue(pool.initialized(), "Pool should be initialized");
        assertEq(pool.predictAmount(), predictAmount, "Predict amount mismatch");
        assertEq(pool.cryptoTargated(), cryptoTargeted, "Crypto target mismatch");
        assertEq(pool.oracleAdapter(), address(mockPriceFeed), "Oracle adapter mismatch");
        assertEq(pool.resolveTimestamp(), resolveTimestamp, "Resolve timestamp mismatch");
        assertEq(pool.participationDeadline(), participationDeadline, "Participation deadline mismatch");
        assertEq(pool.minStake(), minStake, "Min stake mismatch");
        assertEq(pool.protocolTreasury(), protocolTreasury, "Protocol treasury mismatch");
        assertEq(address(pool.ftsoV2()), address(mockPriceFeed), "FtsoV2 instance mismatch");
        assertTrue(address(highToken) != address(0), "High token not deployed");
        assertTrue(address(lowToken) != address(0), "Low token not deployed");
        assertEq(highToken.name(), string(abi.encodePacked("HighBet", cryptoTargeted)), "High token name");
        assertEq(highToken.symbol(), string(abi.encodePacked("HIGH", cryptoTargeted)), "High token symbol");
        assertEq(highToken.MAX_SUPPLY(), highBetTokenMaxSupply, "High token max supply");
        assertEq(uint256(highToken.decimals()), POOL_PRECISION, "High token decimals");
        assertEq(lowToken.name(), string(abi.encodePacked("LowBet", cryptoTargeted)), "Low token name");
        assertEq(lowToken.symbol(), string(abi.encodePacked("LOW", cryptoTargeted)), "Low token symbol");
        assertEq(lowToken.MAX_SUPPLY(), lowBetTokenMaxSupply, "Low token max supply");
        assertEq(uint256(lowToken.decimals()), POOL_PRECISION, "Low token decimals");
    }


    // --- Test Prediction ---
    // (No changes needed here)
    function test_Predict_Success() public {
        uint256 aliceStake = 1 ether;
        uint256 bobStake = 0.5 ether;

        // Alice predicts High (true)
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit IMarketPoolCrypto.Predicted(alice, true, uint224(aliceStake));
        vm.expectEmit(true, true, true, true);
        emit IMarketPoolCrypto.HighBetTokenAwarded(alice, aliceStake);
        pool.predict{value: aliceStake}(true, aliceStake);
        vm.stopPrank();

        assertEq(pool.totalStake(), aliceStake, "Total stake after Alice");
        assertEq(pool.stakeForGreaterThan(), aliceStake, "Stake for > after Alice");
        assertEq(pool.forGreaterThan(), 1, "Count for > after Alice");
        assertEq(pool.amountStaked(alice), aliceStake, "Alice stake amount");
        assertTrue(pool.betOn(alice), "Alice bet direction");
        assertEq(highToken.balanceOf(alice), aliceStake, "Alice HighToken balance");

        // Bob predicts Low (false)
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit IMarketPoolCrypto.Predicted(bob, false, uint224(bobStake));
         vm.expectEmit(true, true, true, true);
        emit IMarketPoolCrypto.LowBetTokenAwarded(bob, bobStake);
        pool.predict{value: bobStake}(false, bobStake);
        vm.stopPrank();

        assertEq(pool.totalStake(), aliceStake + bobStake, "Total stake after Bob");
        assertEq(pool.stakeForGreaterThan(), aliceStake, "Stake for > after Bob");
        assertEq(pool.againstGreaterThan(), 1, "Count against > after Bob");
        assertEq(pool.amountStaked(bob), bobStake, "Bob stake amount");
        assertFalse(pool.betOn(bob), "Bob bet direction");
        assertEq(lowToken.balanceOf(bob), bobStake, "Bob LowToken balance");
    }

    function test_Predict_UpdateBet() public {
        uint256 initialStake = 0.5 ether;
        uint256 updatedStake = 1 ether;

        // Alice predicts Low initially
        vm.startPrank(alice);
        pool.predict{value: initialStake}(false, initialStake);
        vm.stopPrank();

        // Alice changes prediction to High
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit IMarketPoolCrypto.Predicted(alice, true, uint224(updatedStake));
        vm.expectEmit(true, true, true, true);
        emit IMarketPoolCrypto.HighBetTokenAwarded(alice, updatedStake);
        pool.predict{value: updatedStake}(true, updatedStake);
        vm.stopPrank();

        assertEq(pool.totalStake(), updatedStake, "Total stake after updated bet");
        assertEq(pool.stakeForGreaterThan(), updatedStake, "Stake for > after updated bet");
        assertEq(pool.forGreaterThan(), 1, "Count for > after updated bet");
        assertEq(pool.againstGreaterThan(), 0, "Count against > after updated bet");
        assertEq(pool.amountStaked(alice), updatedStake, "Alice stake after updated bet");
        assertTrue(pool.betOn(alice), "Alice bet direction after updated bet");
        assertEq(highToken.balanceOf(alice), updatedStake, "Alice HighToken balance after update");
        // LowTokens from first bet remain (as per contract logic)
        assertEq(lowToken.balanceOf(alice), initialStake, "Alice LowToken balance after update");
    }

    function test_Predict_Fail_DeadlinePassed() public {
        vm.warp(participationDeadline + 1);
        vm.startPrank(alice);
        vm.expectRevert("Participation deadline has passed");
        pool.predict{value: minStake}(true, minStake);
        vm.stopPrank();
    }

    function test_Predict_Fail_PoolResolved() public {
        // Setup: Predict, Resolve
        vm.startPrank(alice);
        pool.predict{value: 1 ether}(true, 1 ether);
        vm.stopPrank();

        // Warp time and set fresh price JUST BEFORE resolving
        vm.warp(resolveTimestamp + 1);
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount + 1, ORACLE_DECIMALS, currentTimestamp);
        pool.resolve(); // Resolve the pool
        assertTrue(pool.resolved(), "Pool should be resolved for test setup");

        // Attempt to predict after resolution
        vm.startPrank(bob);
        vm.expectRevert("Pool is resolving or resolved");
        pool.predict{value: minStake}(false, minStake);
        vm.stopPrank();
    }

    function test_Predict_Fail_BelowMinStake() public {
        uint256 stake = minStake / 2;
        vm.startPrank(alice);
        vm.expectRevert("Staked amount is below minimum");
        pool.predict{value: stake}(true, stake);
        vm.stopPrank();
    }

    function test_Predict_Fail_ValueMismatch() public {
        uint256 stakeAmountArg = 1 ether;
        uint256 valueSent = 0.5 ether;
        vm.startPrank(alice);
        vm.expectRevert("Ether sent and amount passed mismatch");
        pool.predict{value: valueSent}(true, stakeAmountArg);
        vm.stopPrank();
    }

    function test_Predict_Fail_HighTokenMaxSupply() public {
        uint256 lowMaxSupply = 1 ether; // Use a small supply for testing limit
        vm.startPrank(deployer);
        pool = new CryptoMarketPool();
        pool.initialize(
            predictAmount, cryptoTargeted, address(mockPriceFeed),
            resolveTimestamp, participationDeadline, minStake,
            lowMaxSupply, // Low max supply for High token
            lowBetTokenMaxSupply, protocolTreasury
        );
        highToken = IBetToken(pool.highBetToken());
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
        vm.stopPrank(); // Stop deployer prank

        // First bet (should succeed)
        vm.startPrank(alice);
        pool.predict{value: lowMaxSupply}(true, lowMaxSupply);
        vm.stopPrank();
        assertEq(highToken.totalSupply(), lowMaxSupply);

        // Second bet (should fail)
        vm.startPrank(bob);
        vm.expectRevert("Cannot place bet: HighBetToken maximum supply reached");
        pool.predict{value: minStake}(true, minStake); // Predict high again
        vm.stopPrank();
    }

    // --- Test Resolution ---

    function test_Resolve_Success_GreaterThan() public {
        uint256 aliceStake = 1 ether;
        uint256 bobStake = 0.5 ether;
        vm.prank(alice);
        pool.predict{value: aliceStake}(true, aliceStake); // Alice predicts >
        vm.prank(bob);
        pool.predict{value: bobStake}(false, bobStake);   // Bob predicts <=

        // Warp time past resolution
        vm.warp(resolveTimestamp + 1);

        // Set FRESH mock price higher JUST BEFORE resolving
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount + 1 ether, ORACLE_DECIMALS, currentTimestamp);

        // Resolve
        uint256 expectedLosingStake = bobStake;
        uint256 expectedFee = (expectedLosingStake * pool.FEE_PERCENTAGE()) / 100;

        // Expect emit with the timestamp that will be used inside resolve()
        vm.expectEmit(true, false, false, true); // Check only data (greaterThan flag) and topic1 (no, this event has no indexed params)
        // Correction: Resolved event has NO indexed parameters.
        // Signature: event Resolved(bool greaterThan, uint256 timestamp);
        // So we only check data.
        vm.expectEmit(false, false, false, true);
        emit IMarketPoolCrypto.Resolved(true, currentTimestamp);

        pool.resolve();

        assertTrue(pool.resolved(), "Pool should be resolved");
        assertTrue(pool.greaterThan(), "Result should be greaterThan = true");
        assertEq(pool.globalFee(), expectedFee, "Global fee calculation incorrect");
    }

    function test_Resolve_Success_NotGreaterThan() public {
        uint256 aliceStake = 1 ether;
        uint256 bobStake = 0.5 ether;
        vm.prank(alice);
        pool.predict{value: aliceStake}(true, aliceStake);
        vm.prank(bob);
        pool.predict{value: bobStake}(false, bobStake);

        // Warp time past resolution
        vm.warp(resolveTimestamp + 1);

        // Set FRESH mock price lower JUST BEFORE resolving
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount - 1 ether, ORACLE_DECIMALS, currentTimestamp);

        // Resolve
        uint256 expectedLosingStake = aliceStake;
        uint256 expectedFee = (expectedLosingStake * pool.FEE_PERCENTAGE()) / 100;

        // Check only data (bool, uint)
        vm.expectEmit(false, false, false, true);
        emit IMarketPoolCrypto.Resolved(false, currentTimestamp);

        pool.resolve();

        assertTrue(pool.resolved(), "Pool should be resolved");
        assertFalse(pool.greaterThan(), "Result should be greaterThan = false");
        assertEq(pool.globalFee(), expectedFee, "Global fee calculation incorrect");
    }

    function test_Resolve_Fail_TimestampNotReached() public {
        vm.expectRevert("Resolve timestamp not reached");
        pool.resolve();
    }

    function test_Resolve_Fail_AlreadyResolved() public {
        vm.prank(alice);
        pool.predict{value: 1 ether}(true, 1 ether);

        // Warp, set price, resolve once
        vm.warp(resolveTimestamp + 1);
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount + 1, ORACLE_DECIMALS, currentTimestamp);
        pool.resolve();
        assertTrue(pool.resolved(), "Pool resolved for setup");

        // Try resolving again
        vm.expectRevert("Pool already resolved");
        pool.resolve();
    }

    function test_Resolve_Fail_StalePrice() public {
        vm.prank(alice);
        pool.predict{value: 1 ether}(true, 1 ether);

        // Warp time past resolution
        vm.warp(resolveTimestamp + 1);

        // Set a STALE timestamp JUST BEFORE resolving
        uint64 staleTimestamp = uint64(block.timestamp - pool.STALE_PRICE_THRESHOLD() - 1); // Ensure it's just over the threshold
        mockPriceFeed.setPrice(predictAmount + 1, ORACLE_DECIMALS, staleTimestamp); // Use setPrice, but with old timestamp

        vm.expectRevert("Price data is stale");
        pool.resolve();
    }

    // --- Test Claiming Rewards ---

    function test_ClaimRewards_Success_WinnerClaims() public {
        uint256 aliceStake = 2 ether; // Winner
        uint256 bobStake = 1 ether;   // Loser

        // Predict
        vm.prank(alice);
        pool.predict{value: aliceStake}(true, aliceStake);
        vm.prank(bob);
        pool.predict{value: bobStake}(false, bobStake);

        // Warp time past resolution
        vm.warp(resolveTimestamp + 1);

        // Set FRESH price and Resolve (Alice wins)
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount + 1 ether, ORACLE_DECIMALS, currentTimestamp);
        pool.resolve();
        assertTrue(pool.resolved(), "Pool resolved for setup");
        assertTrue(pool.greaterThan(), "greaterThan true for setup");


        // Calculate expected rewards for Alice
        uint256 totalStake = aliceStake + bobStake;
        uint256 losingStake = bobStake;
        uint256 fee = (losingStake * pool.FEE_PERCENTAGE()) / 100;
        uint256 distributablePool = totalStake - fee;
        uint256 aliceWinningTokenBalance = highToken.balanceOf(alice);
        uint256 totalWinningTokenSupply = highToken.totalSupply();
        require(totalWinningTokenSupply > 0, "Test setup error: No winning tokens"); // Sanity check test setup

        uint256 aliceTotalNativeReward = (aliceWinningTokenBalance * distributablePool) / totalWinningTokenSupply;
        uint256 expectedUserReward = (aliceTotalNativeReward * 90) / 100;
        uint256 expectedProtocolReward = aliceTotalNativeReward - expectedUserReward;

        // Check initial balances
        uint256 aliceInitialETH = alice.balance;
        uint256 treasuryInitialETH = protocolTreasury.balance;
        uint256 contractInitialETH = address(pool).balance;
        assertEq(contractInitialETH, totalStake, "Contract ETH incorrect before claim");

        // Alice claims rewards
        vm.startPrank(alice);
        // Event: RewardClaimed(address indexed user, uint256 userReward, uint256 protocolReward);
        // Check topic1 (user) and data (rewards)
        vm.expectEmit(true, false, false, true);
        emit IMarketPoolCrypto.RewardClaimed(alice, expectedUserReward, expectedProtocolReward);
        pool.claimRewards();
        vm.stopPrank();

        // Check outcomes
        assertTrue(pool.rewardClaimed(alice), "Alice reward should be marked claimed");
        assertEq(highToken.balanceOf(alice), 0, "Alice winning tokens should be burned");
        assertEq(highToken.totalSupply(), 0, "Winning token total supply should be 0"); // Assuming only one winner

        // Check ETH transfers precisely
        assertEq(alice.balance, aliceInitialETH + expectedUserReward, "Alice ETH balance incorrect");
        assertEq(protocolTreasury.balance, treasuryInitialETH + expectedProtocolReward, "Treasury ETH balance incorrect");
        assertEq(address(pool).balance, contractInitialETH - expectedUserReward - expectedProtocolReward, "Pool ETH balance incorrect");
        assertEq(address(pool).balance, 0, "Pool should be empty after claim"); // Simplified check
    }

    function test_ClaimRewards_Fail_LoserClaims() public {
        uint256 aliceStake = 2 ether; // Winner
        uint256 bobStake = 1 ether;   // Loser

        // Predict
        vm.prank(alice);
        pool.predict{value: aliceStake}(true, aliceStake);
        vm.prank(bob);
        pool.predict{value: bobStake}(false, bobStake);

        // Warp time past resolution
        vm.warp(resolveTimestamp + 1);

        // Set FRESH price and Resolve (Alice wins)
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount + 1 ether, ORACLE_DECIMALS, currentTimestamp);
        pool.resolve();
        assertTrue(pool.resolved(), "Pool resolved for setup");

        // Bob (loser) attempts to claim
        vm.startPrank(bob);
        // Bob holds LowBetToken, but HighBetToken is the winning one. Check should fail on balance > 0 for winning token.
        vm.expectRevert("No winning tokens held or already claimed");
        pool.claimRewards();
        vm.stopPrank();
    }

    function test_ClaimRewards_Fail_NotResolved() public {
        vm.prank(alice);
        pool.predict{value: 1 ether}(true, 1 ether);

        // Attempt claim before resolving
        vm.startPrank(alice);
        vm.expectRevert("Campaign not yet resolved");
        pool.claimRewards();
        vm.stopPrank();
    }

    function test_ClaimRewards_Fail_AlreadyClaimed() public {
        // Predict
        vm.prank(alice);
        pool.predict{value: 1 ether}(true, 1 ether); // Alice predicts >

        // Warp, set price, resolve
        vm.warp(resolveTimestamp + 1);
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount + 1 ether, ORACLE_DECIMALS, currentTimestamp);
        pool.resolve();
        assertTrue(pool.resolved(), "Pool resolved for setup");


        // Alice claims successfully
        vm.prank(alice);
        pool.claimRewards();
        assertTrue(pool.rewardClaimed(alice), "Reward claimed for setup");


        // Alice tries to claim again
        vm.startPrank(alice); // Need prank again
        vm.expectRevert("Reward already claimed");
        pool.claimRewards();
        vm.stopPrank();
    }

    function test_ClaimRewards_Fail_NoStake() public {
        // Predict (only Alice stakes)
        vm.prank(alice);
        pool.predict{value: 1 ether}(true, 1 ether); // Alice predicts >

        // Warp, set price, resolve
        vm.warp(resolveTimestamp + 1);
        uint64 currentTimestamp = uint64(block.timestamp);
        mockPriceFeed.setPrice(predictAmount + 1 ether, ORACLE_DECIMALS, currentTimestamp);
        pool.resolve();
        assertTrue(pool.resolved(), "Pool resolved for setup");

        // Bob (who didn't participate) tries to claim
        vm.startPrank(bob);
        // Should fail because Bob's balance of the winning token (HighBetToken) is 0.
        vm.expectRevert("No winning tokens held or already claimed"); // <<< CORRECTED REVERT MESSAGE
        pool.claimRewards();
        vm.stopPrank();
    }
}