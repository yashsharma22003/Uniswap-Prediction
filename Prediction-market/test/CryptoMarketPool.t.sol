// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "../src/CryptoMarketPool.sol";
// // Use the actual interface definition if available, otherwise define locally or import mock
// import {IMarketPoolCrypto} from "../src/CryptoMarketPool.sol"; // Use the interface from the contract itself
// import {IFtsoV2PriceFeed} from "../src/CryptoMarketPool.sol"; // Use the interface from the contract itself
// // You might need a mock implementation for FtsoV2PriceFeed if the imported one is just an interface
// import "../src/FtsoV2PriceFeed.sol"; // Assuming this contains a mock implementation as used in the original test
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {console} from "forge-std/console.sol";


// contract CryptoMarketPoolEdgeTest is Test {
//     CryptoMarketPool public pool;
//     FtsoV2PriceFeed public priceFeed;
//     address public oracleAdapter;
//     address public user1;
//     address public user2;
//     address public user3; // Additional user for some tests
//     address public nonParticipant;
//     address public rewardToken; // Keep for compatibility, though using native tokens

//     // --- Initialization Parameters ---
//     uint256 public predictAmount = 1000 * 10 ** 18;
//     uint256 public minStake = 0.5 ether;
//     uint256 public initialBalance = 10 ether;
//     uint256 public participationDuration = 12 hours;
//     uint256 public resolutionDelay = 1 days;
//     string public constant TARGET_CRYPTO = "BTC";
//     int8 public constant ORACLE_DECIMALS = 18;

//     // --- Mock Oracle Return Values ---
//     uint256 priceAbove = 1200 * 10 ** 18;
//     uint256 priceBelow = 800 * 10 ** 18;
//     uint256 priceEqual = 1000 * 10 ** 18;


//     // Set up the initial conditions
//     function setUp() public {
//         // Deploy the FtsoV2PriceFeed mock
//         string[] memory cryptoSymbols = new string[](1);
//         cryptoSymbols[0] = TARGET_CRYPTO;
//         bytes21[] memory feedIds = new bytes21[](1);
//         feedIds[0] = bytes21(0x014254432f55534400000000000000000000000000); // BTC/USD

//         priceFeed = new FtsoV2PriceFeed(cryptoSymbols, feedIds);
//         oracleAdapter = address(priceFeed);

//         // Deploy the CryptoMarketPool contract
//         pool = new CryptoMarketPool();

//         // Define timestamps based on current block time
//         uint256 currentTimestamp = block.timestamp;
//         uint256 participationDeadline = currentTimestamp + participationDuration;
//         uint256 resolveTimestamp = participationDeadline + resolutionDelay; // Resolve after participation ends


//         // Initialize the contract
//         pool.initialize(
//             predictAmount,
//             TARGET_CRYPTO,
//             oracleAdapter,
//             resolveTimestamp,
//             participationDeadline,
//             minStake,
//             address(0) // Native token rewards
//         );

//         // Set up user addresses
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
//         user3 = makeAddr("user3");
//         nonParticipant = makeAddr("nonParticipant");

//         // Fund user accounts
//         deal(user1, initialBalance);
//         deal(user2, initialBalance);
//         deal(user3, initialBalance);
//         deal(nonParticipant, initialBalance); // Fund even if not participating initially
//     }

//     // --- Initialization Edge Cases ---

//     function test_RevertIf_InitializeTwice() public {
//         // Deploy a BRAND NEW pool instance specifically for this test
//         CryptoMarketPool localPool = new CryptoMarketPool();

//         // Define initialization parameters (can reuse from class variables or define locally)
//         uint256 currentTimestamp = block.timestamp;
//         // Use short, distinct timestamps to avoid clashes with setUp instance if it matters
//         uint256 participationDeadline = currentTimestamp + 1 hours;
//         uint256 resolveTimestamp = participationDeadline + 2 hours;

//         // FIRST INITIALIZATION (should succeed)
//         localPool.initialize(
//             predictAmount,
//             TARGET_CRYPTO,
//             oracleAdapter, // Use the same mock oracle adapter address from setUp
//             resolveTimestamp,
//             participationDeadline,
//             minStake,
//             address(0)
//         );

//         // Confirm the local instance is initialized
//         assertTrue(localPool.initialized(), "Local pool instance should be initialized");

//         // --- ACT & ASSERT ---
//         // Define the exact expected revert message bytes
//         bytes memory expectedRevert = bytes("Contract already initialized");

//         // Use vm.expectRevert with the exact bytes
//         vm.expectRevert(expectedRevert);

//         // SECOND INITIALIZATION attempt on the SAME local instance (should revert)
//         localPool.initialize(
//             predictAmount,
//             TARGET_CRYPTO,
//             oracleAdapter,
//             resolveTimestamp + 1 days, // Use slightly different params just to ensure it's a distinct call
//             participationDeadline + 1 days,
//             minStake,
//             address(0)
//         );
//     }

//     function test_RevertIf_InitializeInvalidDeadline() public {
//         CryptoMarketPool newPool = new CryptoMarketPool();
//         uint256 currentTimestamp = block.timestamp;
//         uint256 resolveTs = currentTimestamp + 1 days;
//         uint256 deadlineTs = resolveTs + 1 hours; // Deadline AFTER resolution

//         vm.expectRevert("Deadline must be before resolution");
//         newPool.initialize(
//             predictAmount, TARGET_CRYPTO, oracleAdapter,
//             resolveTs, deadlineTs, // Invalid timestamps
//             minStake, address(0)
//         );
//     }

//     function test_RevertIf_InitializeZeroOracle() public {
//         CryptoMarketPool newPool = new CryptoMarketPool();
//         uint256 currentTimestamp = block.timestamp;
//         uint256 participationDeadline = currentTimestamp + participationDuration;
//         uint256 resolveTimestamp = participationDeadline + resolutionDelay;

//         vm.expectRevert("Invalid oracle address");
//         newPool.initialize(
//             predictAmount, TARGET_CRYPTO, address(0), // Zero oracle address
//             resolveTimestamp, participationDeadline,
//             minStake, address(0)
//         );
//     }


//     // --- Prediction Edge Cases ---

//     function test_RevertIf_PredictAfterDeadline() public {
//         vm.warp(pool.participationDeadline() + 1 seconds); // Move time just past the deadline
//         vm.prank(user1);
//         vm.expectRevert("Participation deadline has passed");
//         pool.predict{value: minStake}(true, minStake);
//     }

//     function test_RevertIf_PredictBelowMinStake() public {
//         uint256 amountBelowMin = minStake - 1 wei; // Wei is the smallest unit
//         // Ensure user has enough balance, but send less than minStake
//         deal(user1, minStake);
//         vm.prank(user1);
//         vm.expectRevert("Staked amount is below minimum");
//         pool.predict{value: amountBelowMin}(true, amountBelowMin);
//     }

//     function test_RevertIf_PredictValueMismatch() public {
//         uint256 stakeAmount = 1 ether;
//         uint256 sentValue = 0.9 ether; // Different from stakeAmount
//         vm.prank(user1);
//         vm.expectRevert("Ether sent and amount passed mismatch");
//         pool.predict{value: sentValue}(true, stakeAmount); // Mismatch here
//     }

//     function test_RevertIf_PredictAfterResolve() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);

//         vm.warp(pool.resolveTimestamp() + 1); // Time is past deadline AND resolution time
//         mockOraclePrice(priceAbove, ORACLE_DECIMALS, uint64(block.timestamp));
//         pool.resolve();
//         assertTrue(pool.resolved());

//         vm.prank(user2);
//         // Expecting revert because deadline has passed (this check comes first in the function)
//         vm.expectRevert(bytes("Participation deadline has passed")); // CORRECTED EXPECTED REVERT
//         pool.predict{value: 1 ether}(false, 1 ether);
//     }

//     // --- Tests that should PASS (no revert expected) ---

//     function test_RebetChangeStake() public {
//         vm.prank(user1);
//         pool.predict{value: minStake}(true, minStake);
//         assertEq(pool.amountStaked(user1), minStake);
//         assertEq(pool.totalStake(), minStake);
//         assertEq(pool.stakeForGreaterThan(), minStake);
//         assertEq(pool.forGreaterThan(), 1);
//         assertEq(pool.againstGreaterThan(), 0);

//         uint256 increasedStake = minStake + 1 ether;
//         vm.prank(user1);
//         pool.predict{value: increasedStake}(true, increasedStake);

//         assertEq(pool.amountStaked(user1), increasedStake, "User stake should be updated");
//         assertEq(pool.totalStake(), increasedStake, "Total stake should reflect the change");
//         assertEq(pool.stakeForGreaterThan(), increasedStake, "Stake for 'true' should be updated");
//         assertEq(pool.forGreaterThan(), 1, "Bet count for 'true' should remain 1 (same user)");
//         assertEq(pool.againstGreaterThan(), 0);
//     }

//     function test_RebetChangePrediction() public {
//         uint256 initialStake = 1 ether;
//         vm.prank(user1);
//         pool.predict{value: initialStake}(true, initialStake);
//         assertEq(pool.amountStaked(user1), initialStake);
//         assertEq(pool.betOn(user1), true);
//         assertEq(pool.totalStake(), initialStake);
//         assertEq(pool.stakeForGreaterThan(), initialStake);
//         assertEq(pool.forGreaterThan(), 1);
//         assertEq(pool.againstGreaterThan(), 0);

//         vm.prank(user1);
//         pool.predict{value: initialStake}(false, initialStake);

//         assertEq(pool.amountStaked(user1), initialStake, "User stake amount should remain");
//         assertEq(pool.betOn(user1), false, "User prediction should change to false");
//         assertEq(pool.totalStake(), initialStake, "Total stake should remain the same");
//         assertEq(pool.stakeForGreaterThan(), 0, "Stake for 'true' should be zero now");
//         assertEq(pool.forGreaterThan(), 0, "Count for 'true' should be zero");
//         assertEq(pool.againstGreaterThan(), 1, "Count for 'false' should be 1");
//     }

//     // --- Resolution Edge Cases ---

//     function test_RevertIf_ResolveBeforeTime() public {
//         vm.expectRevert("Resolve timestamp not reached");
//         pool.resolve();
//     }

//     function test_RevertIf_ResolveTwice() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);

//         vm.warp(pool.resolveTimestamp() + 1);
//         mockOraclePrice(priceAbove, ORACLE_DECIMALS, uint64(block.timestamp));

//         pool.resolve();
//         assertTrue(pool.resolved());

//         vm.expectRevert("Pool already resolved");
//         pool.resolve();
//     }

//     function test_RevertIf_ResolveStalePrice() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);

//         vm.warp(pool.resolveTimestamp() + 1);

//         uint64 staleTimestamp = uint64(block.timestamp - pool.STALE_PRICE_THRESHOLD() - 1);
//         mockOraclePrice(priceAbove, ORACLE_DECIMALS, staleTimestamp);

//         vm.expectRevert("Price data is stale");
//         pool.resolve();
//     }

//     function test_ResolvePriceEqualsPredictAmount() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);
//         vm.prank(user2);
//         pool.predict{value: 1 ether}(false, 1 ether);

//         vm.warp(pool.resolveTimestamp() + 1);
//         mockOraclePrice(priceEqual, ORACLE_DECIMALS, uint64(block.timestamp));

//         pool.resolve();

//         assertFalse(pool.greaterThan(), "Outcome should be false when price equals prediction");
//         assertTrue(pool.resolved());
//     }

//     // --- Claiming Edge Cases ---

//     function test_RevertIf_ClaimBeforeResolve() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);

//         vm.prank(user1);
//         vm.expectRevert("Campaign not yet resolved");
//         pool.claimRewards();
//     }

//     function test_RevertIf_ClaimWithoutBet() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);
//         vm.prank(user2);
//         pool.predict{value: 1 ether}(false, 1 ether);

//         vm.warp(pool.resolveTimestamp() + 1);
//         mockOraclePrice(priceAbove, ORACLE_DECIMALS, uint64(block.timestamp));
//         pool.resolve();

//         vm.prank(nonParticipant);
//         vm.expectRevert("No bet found for user");
//         pool.claimRewards();
//     }

//     function test_RevertIf_ClaimTwice() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);
//         vm.prank(user2);
//         pool.predict{value: 1 ether}(false, 1 ether);

//         vm.warp(pool.resolveTimestamp() + 1);
//         mockOraclePrice(priceAbove, ORACLE_DECIMALS, uint64(block.timestamp));
//         pool.resolve();

//         uint256 balanceBefore = user1.balance;
//         vm.prank(user1);
//         pool.claimRewards();
//         assertTrue(user1.balance > balanceBefore);
//         assertTrue(pool.rewardClaimed(user1));

//         vm.prank(user1);
//         vm.expectRevert("Reward already claimed");
//         pool.claimRewards();
//     }

//     function test_RevertIf_ClaimLoser() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether); // User1 bets true
//         vm.prank(user2);
//         pool.predict{value: 1 ether}(false, 1 ether); // User2 bets false

//         vm.warp(pool.resolveTimestamp() + 1);
//         mockOraclePrice(priceBelow, ORACLE_DECIMALS, uint64(block.timestamp)); // False wins
//         pool.resolve();
//         assertFalse(pool.greaterThan());

//         uint256 balanceBefore = user1.balance;
//         vm.prank(user1); // User1 (loser) tries to claim
//         vm.expectRevert(bytes("You lost the bet, no rewards")); // Expect exact revert string
//         pool.claimRewards();

//         // Check balance didn't increase
//         assertEq(user1.balance, balanceBefore);
//         // Check they are NOT marked claimed because the state change was rolled back by revert
//         assertFalse(pool.rewardClaimed(user1), "Loser should NOT be marked claimed after revert");
//     }

//     function test_ClaimOnlyWinners() public {
//         vm.prank(user1);
//         pool.predict{value: 1 ether}(true, 1 ether);
//         vm.prank(user2);
//         pool.predict{value: 2 ether}(true, 2 ether);

//         assertEq(pool.totalStake(), 3 ether);
//         assertEq(pool.stakeForGreaterThan(), 3 ether);

//         vm.warp(pool.resolveTimestamp() + 1);
//         mockOraclePrice(priceAbove, ORACLE_DECIMALS, uint64(block.timestamp));
//         pool.resolve();
//         assertTrue(pool.greaterThan());

//         uint256 totalLosingStake = pool.totalStake() - pool.stakeForGreaterThan();
//         assertEq(totalLosingStake, 0);
//         assertEq(pool.globalFee(), 0);

//         uint256 balance1Before = user1.balance;
//         vm.prank(user1);
//         pool.claimRewards();
//         assertEq(user1.balance, balance1Before + 1 ether, "User1 should get only stake back");
//         assertTrue(pool.rewardClaimed(user1));

//         uint256 balance2Before = user2.balance;
//         vm.prank(user2);
//         pool.claimRewards();
//         assertEq(user2.balance, balance2Before + 2 ether, "User2 should get only stake back");
//         assertTrue(pool.rewardClaimed(user2));
//     }


//     // --- Fee Calculation Edge Cases ---
//     function test_FeeCalculation() public {
//         uint256 stake1 = 2 ether;
//         uint256 stake2 = 3 ether;
//         vm.prank(user1);
//         pool.predict{value: stake1}(true, stake1);
//         vm.prank(user2);
//         pool.predict{value: stake2}(false, stake2);

//         assertEq(pool.totalStake(), stake1 + stake2);
//         assertEq(pool.stakeForGreaterThan(), stake1);

//         vm.warp(pool.resolveTimestamp() + 1);
//         mockOraclePrice(priceAbove, ORACLE_DECIMALS, uint64(block.timestamp));
//         pool.resolve();
//         assertTrue(pool.greaterThan());

//         uint256 expectedFee = (stake2 * pool.FEE_PERCENTAGE()) / 100;
//         assertEq(pool.globalFee(), expectedFee, "Fee calculation mismatch");

//         uint256 balance1Before = user1.balance;
//         vm.prank(user1);
//         pool.claimRewards();

//         uint256 totalWinningStake = stake1;
//         uint256 totalLosingStake = stake2;
//         uint256 netLosingPool = totalLosingStake > expectedFee ? totalLosingStake - expectedFee : 0; // Added check for safety
//         uint256 expectedReward = stake1 + (stake1 * netLosingPool) / totalWinningStake;

//         assertEq(user1.balance, balance1Before + expectedReward, "Winner reward calculation mismatch");
//         assertTrue(pool.rewardClaimed(user1));
//     }


//     // --- Helper Functions ---

//     /// @notice Mocks the FtsoV2PriceFeed return value for the target crypto.
//     function mockOraclePrice(uint256 _price, int8 _decimals, uint64 _timestamp) internal {
//         vm.mockCall(
//             oracleAdapter, // Address of the mock FtsoV2PriceFeed contract
//             abi.encodeWithSelector(
//                 IFtsoV2PriceFeed.getPriceFeed.selector,
//                 TARGET_CRYPTO // The crypto symbol being targeted
//             ),
//             abi.encode(_price, _decimals, _timestamp) // Encoded return values
//         );
//     }
// }
