//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IMarketPool } from "./interface/IMarketPool.sol";

contract StatementMarketPool is IMarketPool {
    string public question;
    address public oracleAdapter;
    uint256 public resolveTimestamp;
    uint256 public participationDeadline;
    uint256 public minStake;
    address public rewardToken;
    bool public initialized = false;

    // ... (rest of the StatementMarketPool logic - state variables, functions for prediction, resolution, claiming rewards) ...

    event PredictedStatemnt(address indexed user,bytes32 prediction,uint256 stake);

    modifier onlyInitialized() {
        require(initialized, "Contract not initialized");
        _;
    }

    function initialize(
        string memory _question,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _rewardToken
    ) external override {
        require(!initialized, "Contract already initialized");
        question = _question;
        oracleAdapter = _oracleAdapter;
        resolveTimestamp = _resolveTimestamp;
        participationDeadline = _participationDeadline;
        minStake = _minStake;
        rewardToken = _rewardToken;
        initialized = true;
    }

    function predict(bytes32 _prediction, uint256 _stakeAmount) external payable onlyInitialized {
        require(block.timestamp < participationDeadline, "Participation deadline has passed");
        require(msg.value >= minStake, "Staked amount is below minimum");
        // ... (record prediction and stake) ...
        emit PredictedStatemnt(msg.sender, _prediction, msg.value);
    }

    function resolve() external onlyInitialized {
        require(block.timestamp >= resolveTimestamp, "Resolve timestamp not reached");
        // ... (fetch statement truth from oracleAdapter and determine outcome) ...
        bool outcome = false; // Placeholder
        emit Resolved(outcome, block.timestamp);
        // ... (mark as resolved) ...
    }

    function claimRewards() external onlyInitialized {
        require(block.timestamp > resolveTimestamp, "Campaign not yet resolved");
        // ... (calculate and transfer rewards to winners) ...
        emit RewardClaimed(msg.sender, 50); // Placeholder reward amount
    }
}
