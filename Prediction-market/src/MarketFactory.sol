// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import { CryptoMarketPool } from "./CryptoMarketPool.sol";
import { StatementMarketPool } from "./StatementMarketPool.sol";

contract MarketFactory is Ownable {
    event CryptoCampaignDeployed(address indexed campaignAddress, address indexed creator, string question, address oracleAdapter, uint256 resolveTimestamp);
    event StatementCampaignDeployed(address indexed campaignAddress, address indexed creator, string question, address oracleAdapter, uint256 resolveTimestamp);

    constructor() Ownable(msg.sender) {}

    function deployCryptoCampaign(
        uint256 _predictAmount,
        string memory _cryptoTargated,
        address _ftsOracleAdapter, // Address of the FTSO Oracle Adapter contract
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _rewardToken,
        uint256 _highBetTokenMaxSupply,
        uint256 _lowBetTokenMaxSupply,
        address _protocolTreasury
    ) public payable returns (address campaignAddress) {
        require(_resolveTimestamp > block.timestamp, "Resolve timestamp must be in the future");
        require(_participationDeadline < _resolveTimestamp, "Participation deadline must be before resolve timestamp");
        require(_minStake > 0, "Minimum stake must be greater than zero");
        require(_rewardToken != address(0), "Reward token address cannot be zero");

        CryptoMarketPool newCampaign = new CryptoMarketPool();
        newCampaign.initialize(
        _predictAmount,
        _cryptoTargated,
        _ftsOracleAdapter,
        _resolveTimestamp,
        _participationDeadline,
        _minStake,
        _highBetTokenMaxSupply,
        _lowBetTokenMaxSupply,
        _protocolTreasury
    );
        campaignAddress = address(newCampaign);

        emit CryptoCampaignDeployed(campaignAddress, msg.sender, _cryptoTargated, _ftsOracleAdapter, _resolveTimestamp);
        return campaignAddress;
    }

    function deployStatementCampaign(
        string memory _question,
        address _fdcOracleAdapter, // Address of the FDC Oracle Adapter contract
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _rewardToken
    ) public payable returns (address campaignAddress) {
        require(_resolveTimestamp > block.timestamp, "Resolve timestamp must be in the future");
        require(_participationDeadline < _resolveTimestamp, "Participation deadline must be before resolve timestamp");
        require(_minStake > 0, "Minimum stake must be greater than zero");
        require(_rewardToken != address(0), "Reward token address cannot be zero");

        StatementMarketPool newCampaign = new StatementMarketPool();
        newCampaign.initialize(
            _question,
            _fdcOracleAdapter,
            _resolveTimestamp,
            _participationDeadline,
            _minStake,
            _rewardToken
        );
        campaignAddress = address(newCampaign);

        emit StatementCampaignDeployed(campaignAddress, msg.sender, _question, _fdcOracleAdapter, _resolveTimestamp);
        return campaignAddress;
    }
}