// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol"; // Import Vm for cheatcodes

// Import the contract under test
import { CryptoMarketPoolToken } from "../src/CryptoMarketPoolToken.sol";

// Import interfaces used by the contract
import { IBetToken } from "../src/interface/IBetToken.sol"; // Assuming this path
import { IMockFtsoV2PriceFeed } from "../src/interface/IMockFtsoV2PriceFeed.sol"; // Assuming this path
import {MockFtsoV2PriceFeed} from "../src/Mock/MockFtsoV2PriceFeed.sol";

// --- Mock Contracts for Dependencies ---

// Mock for IBetToken
// Simulates minting, total supply, and max supply
contract MockBetToken is IBetToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply = 0;
    uint256 public MAX_SUPPLY = type(uint256).max; // Default to a large value, can be set

    // Allow setting max supply for specific tests
    function setMaxSupply(uint256 _maxSupply) public {
        MAX_SUPPLY = _maxSupply;
    }

    // Mock implementation of mint
    function mint(address to, uint256 amount) external override {
        require(totalSupply + amount <= MAX_SUPPLY, "Mock: Max supply reached");
        balances[to] += amount;
        totalSupply += amount;
        // In a real token, you might emit a Transfer event from address(0)
    }

    // Mock implementation of burn (if needed by the contract, not currently)
    function burn(address from, uint256 amount) external override {
         require(balances[from] >= amount, "Mock: Insufficient balance");
         balances[from] -= amount;
         totalSupply -= amount;
         // In a real token, you might emit a Transfer event to address(0)
    }

    // Mock implementation of transfer (if needed by the contract, not currently)
    function transfer(address to, uint256 amount) external returns (bool) {
         require(balances[msg.sender] >= amount, "Mock: Insufficient balance");
         balances[msg.sender] -= amount;
         balances[to] += amount;
         return true;
    }

    // Mock implementation of transferFrom (if needed by the contract, not currently)
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        // Requires allowance logic if needed
         require(balances[from] >= amount, "Mock: Insufficient balance");
         balances[from] -= amount;
         balances[to] += amount;
         return true;
    }

    // Mock implementation of approve (if needed by the contract, not currently)
    function approve(address spender, uint256 amount) external returns (bool) {
         // Allowance logic needed
         return true;
    }

    // Mock implementation of allowance (if needed by the contract, not currently)
    function allowance(address owner, address spender) external view  returns (uint256) {
         // Allowance logic needed
         return 0; // Default
    }

    // Mock implementation of balanceOf (if needed by the contract, not currently)
    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

     // Mock implementation of decimals (if needed by the contract, not currently)
    function decimals() external view override returns (uint8) {
        return 18; // Default
    }

     // Mock implementation of symbol (if needed by the contract, not currently)
    function symbol() external view override returns (string memory) {
        return "MBT"; // Mock Bet Token
    }

     // Mock implementation of name (if needed by the contract, not currently)
    function name() external view override returns (string memory) {
        return "Mock Bet Token";
    }
}

contract CryptoMarketPoolTokenTest is Test {
    CryptoMarketPoolToken public marketPool;
    MockBetToken public mockHighBetToken;
    MockBetToken public mockLowBetToken;
    MockFtsoV2PriceFeed public mockFtsoV2;

    string public _symbol;

    // Test parameters for initialization
    uint256 public constant PREDICT_AMOUNT = 50000e18; // Example: $50,000 with 18 decimals
    string public constant CRYPTO_TARGETED = "BTC/USD";
    uint256 public constant RESOLVE_TIMESTAMP = 200; // Example timestamp
    uint256 public constant PARTICIPATION_DEADLINE = 100; // Example timestamp
    uint256 public constant MIN_STAKE = 1e18; // Example: 1 native token
    address public constant REWARD_TOKEN = address(0); // Using native token for reward


    event Predicted(
        address indexed user,
        bool indexed prediction,
        uint256 amount
    );
    event Resolved(bool indexed greaterThan, uint256 indexed timestamp);
    event RewardClaimed(address indexed user, uint256 amount);
    // NEW Events for specific token awards
    event HighBetTokenAwarded(address indexed user, uint256 amount);
    event LowBetTokenAwarded(address indexed user, uint256 amount);

    // User addresses for testing
    address public constant USER1 = address(101);
    address public constant USER2 = address(102);
    address public constant USER3 = address(103);
    address public constant PROTOCOL_TREASURY = address(999); // Assuming a treasury address

    function setUp() public {
        // Deploy mock contracts
        mockHighBetToken = new MockBetToken();
        mockLowBetToken = new MockBetToken();
        mockFtsoV2 = new MockFtsoV2PriceFeed(_symbol);

        // Deploy the contract under test
        marketPool = new CryptoMarketPoolToken();

        // Set the protocol treasury address (assuming a setter or it's set during deployment)
        // Since there's no setter in the provided code, we'll assume it's set somehow,
        // or we can add a setter for testing purposes if needed.
        // For now, we'll manually set it using cheatcodes if necessary for tests that use it.
        // vm.store(address(marketPool), bytes32(uint256(0)), bytes32(uint256(uint160(PROTOCOL_TREASURY)))); // Example if protocolTreasury is the first state variable

        // Initialize the market pool contract
        vm.prank(address(this)); // Prank with the test contract address for initialization
        marketPool.initialize(
            PREDICT_AMOUNT,
            CRYPTO_TARGETED,
            address(mockFtsoV2), // Use mock FtsoV2 address
            RESOLVE_TIMESTAMP,
            PARTICIPATION_DEADLINE,
            MIN_STAKE,
            REWARD_TOKEN,
            address(mockHighBetToken), // Use mock HighBetToken address
            address(mockLowBetToken) // Use mock LowBetToken address
        );
    }

    // --- Test Initialization ---

    function test_Initialize_Success() public {
        // Check if state variables are set correctly
        assertEq(marketPool.predictAmount(), PREDICT_AMOUNT);
        assertEq(marketPool.cryptoTargated(), CRYPTO_TARGETED);
        assertEq(marketPool.oracleAdapter(), address(mockFtsoV2));
        assertEq(marketPool.resolveTimestamp(), RESOLVE_TIMESTAMP);
        assertEq(marketPool.participationDeadline(), PARTICIPATION_DEADLINE);
        assertEq(marketPool.minStake(), MIN_STAKE);
        assertEq(marketPool.rewardToken(), REWARD_TOKEN);
        assertTrue(marketPool.initialized());
        assertEq(address(marketPool.ftsoV2()), address(mockFtsoV2));
        assertEq(address(marketPool.highBetToken()), address(mockHighBetToken));
        assertEq(address(marketPool.lowBetToken()), address(mockLowBetToken));
    }

    function test_Initialize_AlreadyInitialized_Reverts() public {
        vm.expectRevert("Contract already initialized");
        marketPool.initialize(
            PREDICT_AMOUNT,
            CRYPTO_TARGETED,
            address(mockFtsoV2),
            RESOLVE_TIMESTAMP,
            PARTICIPATION_DEADLINE,
            MIN_STAKE,
            REWARD_TOKEN,
            address(mockHighBetToken),
            address(mockLowBetToken)
        );
    }

    function test_Initialize_InvalidOracleAddress_Reverts() public {
        // Deploy a new instance to test initialization failure
        CryptoMarketPoolToken newMarketPool = new CryptoMarketPoolToken();
        vm.expectRevert("Invalid oracle address");
        newMarketPool.initialize(
            PREDICT_AMOUNT,
            CRYPTO_TARGETED,
            address(0), // Invalid address
            RESOLVE_TIMESTAMP,
            PARTICIPATION_DEADLINE,
            MIN_STAKE,
            REWARD_TOKEN,
            address(mockHighBetToken),
            address(mockLowBetToken)
        );
    }

    function test_Initialize_DeadlineAfterResolution_Reverts() public {
         // Deploy a new instance to test initialization failure
        CryptoMarketPoolToken newMarketPool = new CryptoMarketPoolToken();
        vm.expectRevert("Deadline must be before resolution");
        newMarketPool.initialize(
            PREDICT_AMOUNT,
            CRYPTO_TARGETED,
            address(mockFtsoV2),
            PARTICIPATION_DEADLINE, // Resolution before deadline
            RESOLVE_TIMESTAMP,
            MIN_STAKE,
            REWARD_TOKEN,
            address(mockHighBetToken),
            address(mockLowBetToken)
        );
    }

     function test_Initialize_InvalidHighBetTokenAddress_Reverts() public {
         // Deploy a new instance to test initialization failure
        CryptoMarketPoolToken newMarketPool = new CryptoMarketPoolToken();
        vm.expectRevert("Invalid HighBetToken address");
        newMarketPool.initialize(
            PREDICT_AMOUNT,
            CRYPTO_TARGETED,
            address(mockFtsoV2),
            RESOLVE_TIMESTAMP,
            PARTICIPATION_DEADLINE,
            MIN_STAKE,
            REWARD_TOKEN,
            address(0), // Invalid HighBetToken address
            address(mockLowBetToken)
        );
    }

     function test_Initialize_InvalidLowBetTokenAddress_Reverts() public {
         // Deploy a new instance to test initialization failure
        CryptoMarketPoolToken newMarketPool = new CryptoMarketPoolToken();
        vm.expectRevert("Invalid LowBetToken address");
        newMarketPool.initialize(
            PREDICT_AMOUNT,
            CRYPTO_TARGETED,
            address(mockFtsoV2),
            RESOLVE_TIMESTAMP,
            PARTICIPATION_DEADLINE,
            MIN_STAKE,
            REWARD_TOKEN,
            address(mockHighBetToken),
            address(0) // Invalid LowBetToken address
        );
    }


    // --- Test predict Function ---

    function test_Predict_High_Success() public {
        uint256 stakeAmount = 2e18; // 2 native tokens
        vm.deal(USER1, stakeAmount); // Give USER1 some native tokens

        vm.prank(USER1);
        vm.expectEmit(true, true, false, true); // Predicted event
        emit Predicted(USER1, true, stakeAmount);
        vm.expectEmit(true, true, false, true); // HighBetTokenAwarded event
        emit HighBetTokenAwarded(USER1, stakeAmount);

        marketPool.predict{value: stakeAmount}(true, stakeAmount);

        // Check state updates
        assertEq(marketPool.forGreaterThan(), 1);
        assertEq(marketPool.againstGreaterThan(), 0);
        assertEq(marketPool.stakeForGreaterThan(), stakeAmount);
        assertEq(marketPool.totalStake(), stakeAmount);
        assertTrue(marketPool.betOn(USER1));
        assertEq(marketPool.amountStaked(USER1), stakeAmount);
        assertEq(marketPool.predictorList(0), USER1); // Check predictor list

        // Check mock BetToken state
        assertEq(mockHighBetToken.balanceOf(USER1), stakeAmount);
        assertEq(mockHighBetToken.totalSupply(), stakeAmount);
        assertEq(mockLowBetToken.balanceOf(USER1), 0);
        assertEq(mockLowBetToken.totalSupply(), 0);
    }

     function test_Predict_Low_Success() public {
        uint256 stakeAmount = 3e18; // 3 native tokens
        vm.deal(USER2, stakeAmount); // Give USER2 some native tokens

        vm.prank(USER2);
        vm.expectEmit(true, true, false, true); // Predicted event
        emit Predicted(USER2, false, stakeAmount);
        vm.expectEmit(true, true, false, true); // LowBetTokenAwarded event
        emit LowBetTokenAwarded(USER2, stakeAmount);

        marketPool.predict{value: stakeAmount}(false, stakeAmount);

        // Check state updates
        assertEq(marketPool.forGreaterThan(), 0);
        assertEq(marketPool.againstGreaterThan(), 1);
        assertEq(marketPool.stakeForGreaterThan(), 0); // Stake for greaterThan is 0
        assertEq(marketPool.totalStake(), stakeAmount);
        assertFalse(marketPool.betOn(USER2));
        assertEq(marketPool.amountStaked(USER2), stakeAmount);
        assertEq(marketPool.predictorList(0), USER2); // Check predictor list

        // Check mock BetToken state
        assertEq(mockHighBetToken.balanceOf(USER2), 0);
        assertEq(mockHighBetToken.totalSupply(), 0);
        assertEq(mockLowBetToken.balanceOf(USER2), stakeAmount);
        assertEq(mockLowBetToken.totalSupply(), stakeAmount);
    }

    function test_Predict_MultipleUsers() public {
        uint256 stake1 = 2e18;
        uint256 stake2 = 3e18;
        vm.deal(USER1, stake1);
        vm.deal(USER2, stake2);

        vm.prank(USER1);
        marketPool.predict{value: stake1}(true, stake1); // USER1 bets High

        vm.prank(USER2);
        marketPool.predict{value: stake2}(false, stake2); // USER2 bets Low

        // Check state updates after both bets
        assertEq(marketPool.forGreaterThan(), 1);
        assertEq(marketPool.againstGreaterThan(), 1);
        assertEq(marketPool.stakeForGreaterThan(), stake1);
        assertEq(marketPool.totalStake(), stake1 + stake2);
        assertEq(marketPool.predictorList(0), USER1);
        assertEq(marketPool.predictorList(1), USER2);

        // Check BetToken states
        assertEq(mockHighBetToken.balanceOf(USER1), stake1);
        assertEq(mockHighBetToken.totalSupply(), stake1);
        assertEq(mockLowBetToken.balanceOf(USER2), stake2);
        assertEq(mockLowBetToken.totalSupply(), stake2);
    }

     function test_Predict_UserUpdatesBet() public {
        uint256 stake1 = 2e18;
        uint256 stake2 = 3e18;
        vm.deal(USER1, stake1 + stake2); // Ensure enough balance

        vm.prank(USER1);
        marketPool.predict{value: stake1}(true, stake1); // USER1 initially bets High

        // Check state after first bet
        assertEq(marketPool.forGreaterThan(), 1);
        assertEq(marketPool.againstGreaterThan(), 0);
        assertEq(marketPool.stakeForGreaterThan(), stake1);
        assertEq(marketPool.totalStake(), stake1);
        assertTrue(marketPool.betOn(USER1));
        assertEq(marketPool.amountStaked(USER1), stake1);
        assertEq(mockHighBetToken.balanceOf(USER1), stake1);
        assertEq(mockHighBetToken.totalSupply(), stake1);
        assertEq(mockLowBetToken.balanceOf(USER1), 0);
        assertEq(mockLowBetToken.totalSupply(), 0);


        vm.prank(USER1);
        marketPool.predict{value: stake2}(false, stake2); // USER1 updates bet to Low

        // Check state after update
        assertEq(marketPool.forGreaterThan(), 0); // Count decreased for High
        assertEq(marketPool.againstGreaterThan(), 1); // Count increased for Low
        assertEq(marketPool.stakeForGreaterThan(), 0); // Stake for High is now 0
        assertEq(marketPool.totalStake(), stake2); // Total stake updated to new amount
        assertFalse(marketPool.betOn(USER1)); // Bet direction updated
        assertEq(marketPool.amountStaked(USER1), stake2); // Staked amount updated

        // Check BetToken states - previous tokens should ideally be handled (burned/transferred)
        // based on IBetToken logic, but the provided contract doesn't explicitly burn/transfer
        // old BetTokens on update. This might be a design consideration or a missing feature.
        // We test based on the provided contract's behavior: new tokens are minted.
        assertEq(mockHighBetToken.balanceOf(USER1), stake1); // Old High tokens remain
        assertEq(mockHighBetToken.totalSupply(), stake1);
        assertEq(mockLowBetToken.balanceOf(USER1), stake2); // New Low tokens minted
        assertEq(mockLowBetToken.totalSupply(), stake2);
    }


    function test_Predict_BelowMinStake_Reverts() public {
        uint256 stakeAmount = MIN_STAKE - 1;
        vm.deal(USER1, stakeAmount);

        vm.prank(USER1);
        vm.expectRevert("Staked amount is below minimum");
        marketPool.predict{value: stakeAmount}(true, stakeAmount);
    }

    function test_Predict_ValueAmountMismatch_Reverts() public {
        uint256 stakeAmount = 2e18;
        vm.deal(USER1, stakeAmount);

        vm.prank(USER1);
        vm.expectRevert("Ether sent and amount passed mismatch");
        marketPool.predict{value: stakeAmount - 1}(true, stakeAmount); // Value sent is less
    }

    function test_Predict_AfterParticipationDeadline_Reverts() public {
        uint256 stakeAmount = 2e18;
        vm.deal(USER1, stakeAmount);

        vm.warp(PARTICIPATION_DEADLINE + 1); // Move time past deadline

        vm.prank(USER1);
        vm.expectRevert("Participation deadline has passed");
        marketPool.predict{value: stakeAmount}(true, stakeAmount);
    }

     function test_Predict_HighBetTokenMaxSupplyReached_Reverts() public {
        uint256 stakeAmount = 10e18;
        vm.deal(USER1, stakeAmount);

        // Set max supply on the mock token to be less than the stake amount
        mockHighBetToken.setMaxSupply(stakeAmount - 1);

        vm.prank(USER1);
        vm.expectRevert("Cannot place bet: HighBetToken maximum supply reached");
        marketPool.predict{value: stakeAmount}(true, stakeAmount);
     }

      function test_Predict_LowBetTokenMaxSupplyReached_Reverts() public {
        uint256 stakeAmount = 10e18;
        vm.deal(USER1, stakeAmount);

        // Set max supply on the mock token to be less than the stake amount
        mockLowBetToken.setMaxSupply(stakeAmount - 1);

        vm.prank(USER1);
        vm.expectRevert("Cannot place bet: LowBetToken maximum supply reached");
        marketPool.predict{value: stakeAmount}(false, stakeAmount);
     }

    // Note: Reentrancy test for predict is implicitly covered by nonReentrant modifier.
    // To explicitly test it, you would need a malicious contract that calls back.

    // --- Test resolve Function ---

    function test_Resolve_ResolveTimestampNotReached_Reverts() public {
        // Place bets
        uint256 highStake = 5e18;
        vm.deal(USER1, highStake);
        vm.warp(PARTICIPATION_DEADLINE - 10);
        vm.prank(USER1);
        marketPool.predict{value: highStake}(true, highStake);

        // Try to resolve before resolve timestamp
        vm.warp(RESOLVE_TIMESTAMP - 1);
        vm.expectRevert("Resolve timestamp not reached");
        marketPool.resolve();
    }


    // Note: Reentrancy test for resolve is implicitly covered by nonReentrant modifier.

    function test_ClaimRewards_NotResolved_Reverts() public {
        uint256 stakeAmount = 2e18;
        vm.deal(USER1, stakeAmount);
        vm.warp(PARTICIPATION_DEADLINE - 10);
        vm.prank(USER1);
        marketPool.predict{value: stakeAmount}(true, stakeAmount);

        // Try to claim before resolution
        vm.warp(RESOLVE_TIMESTAMP - 1);
        vm.prank(USER1);
        vm.expectRevert("Campaign not yet resolved");
        marketPool.claimRewards();
    }
}
