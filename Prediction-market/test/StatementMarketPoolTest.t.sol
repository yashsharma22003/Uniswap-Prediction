// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StatementMarketPool.sol";

contract StatementMarketPoolTest is Test {
    StatementMarketPool pool;

    string question = "Is Ethereum the most secure blockchain?";
    address oracleAdapter = address(0x123);
    uint256 resolveTimestamp;
    uint256 participationDeadline;
    uint256 minStake = 0.1 ether;
    address rewardToken = address(0x456);

    address user = address(0xAB);
    event PredictedStatement(
        address indexed user,
        bytes32 prediction,
        uint256 stake
    );
    event Resolved(bool indexed greaterThan, uint256 indexed timestamp);
    event RewardClaimed(address indexed user, uint256 amount);

    function setUp() public {
        pool = new StatementMarketPool();
        resolveTimestamp = block.timestamp + 1 days;
        participationDeadline = block.timestamp + 12 hours;
        pool.initialize(
            question,
            oracleAdapter,
            resolveTimestamp,
            participationDeadline,
            minStake,
            rewardToken
        );
    }

    function testInitialize_RevertIfCalledTwice() public {
        vm.expectRevert("Contract already initialized");
        pool.initialize(
            question,
            oracleAdapter,
            resolveTimestamp,
            participationDeadline,
            minStake,
            rewardToken
        );
    }

    function testPredict_SuccessfulPrediction() public {
        vm.deal(user, 10 ether); // Give some ETH to the user for the stake
        vm.prank(user); // Set the context to the user

        vm.expectEmit(true, true, false, true);
        emit PredictedStatement(user, bytes32("YES"), minStake);

        pool.predict{value: minStake}(bytes32("YES"), minStake); // Call the predict function
    }

    function testPredict_RevertIfAfterDeadline() public {
        skip(13 hours); // move past participationDeadline
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("Participation deadline has passed");
        pool.predict{value: minStake}(bytes32("NO"), minStake);
    }

    function testPredict_RevertIfStakeTooLow() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("Staked amount is below minimum");
        pool.predict{value: minStake - 1}(bytes32("NO"), minStake - 1);
    }

    function testResolve_RevertIfBeforeResolveTime() public {
        vm.expectRevert("Resolve timestamp not reached");
        pool.resolve();
    }

    function testClaimRewards_RevertIfBeforeResolution() public {
        vm.expectRevert("Campaign not yet resolved");
        pool.claimRewards();
    }

    function testClaimRewards_SuccessAfterResolution() public {
        skip(2 days);
        pool.resolve();

        vm.expectEmit(true, false, false, true);
        emit RewardClaimed(address(this), 50);

        pool.claimRewards();
    }
}
