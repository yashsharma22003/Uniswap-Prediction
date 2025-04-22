//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketPool {
    function initialize(
        string memory _question,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _rewardToken
    ) external;

    event Predicted(address indexed user, bool prediction, uint256 stake);
    event Resolved(bool outcome, uint256 resolvingTimestamp);
    event RewardClaimed(address indexed user, uint256 rewardAmount);
}