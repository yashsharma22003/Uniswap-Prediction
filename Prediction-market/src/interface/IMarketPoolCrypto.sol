//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketPoolCrypto {
    function initialize(
        uint256 predictAmount,
        string memory cryptoTargated,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _rewardToken
    ) external;

    event Predicted(address indexed user, bool prediction, uint256 stake);
    event Resolved(bool outcome, uint256 resolvingTimestamp);
    event RewardClaimed(address indexed user, uint256 rewardAmount);
    event HighBetTokenDeployed(address, uint256);
    event LowBetTokenDeployed(address, uint256);
    event HighBetTokenAwarded(address, uint256);
    event LowBetTokenAwarded(address, uint256);
    event RewardClaimed(address, uint256, uint256);

}