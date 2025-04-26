// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CryptoPool.sol"; // Make sure CryptoPool is importable
import "./BetTokens/BaseBetToken.sol"; // Make sure BaseBetToken is importable

contract MarketFactory is Ownable {
    event CryptoCampaignDeployed(
        address indexed campaignAddress,
        address indexed creator,
        string question, // Note: Original event used 'question', maybe rename _cryptoTargated param or update event
        address oracleAdapter,
        uint256 resolveTimestamp
    );
    // event StatementCampaignDeployed(...) // Potentially other event types

    // --- Constructor ---
    constructor() Ownable(msg.sender) {}

    // --- Deployment Function ---

    /// @notice Deploys a CryptoPool with its High/Low BetTokens.
    /// @dev Deploys pool first, then tokens (setting pool as minter), then initializes pool.
    /// @param _predictAmount The target price amount (scaled to CryptoPool.PRECISION decimals).
    /// @param _cryptoTargated The symbol of the crypto asset (e.g., "BTC/USD") for the oracle.
    /// @param _ftsOracleAdapter The address of the FTSOv2 compatible oracle adapter.
    /// @param _resolveTimestamp Unix timestamp when the market resolves.
    /// @param _participationDeadline Unix timestamp after which betting is closed.
    /// @param _minStake Minimum stake amount required per bet (in wei).
    /// @param _highBetTokenMaxSupply The maximum total supply for the High bet token.
    /// @param _lowBetTokenMaxSupply The maximum total supply for the Low bet token.
    /// @return campaignAddress The address of the newly deployed CryptoPool contract.
    function deployCryptoCampaign(
        uint256 _predictAmount,
        string memory _cryptoTargated,
        address _ftsOracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        uint256 _highBetTokenMaxSupply,
        uint256 _lowBetTokenMaxSupply
    ) external onlyOwner returns (address campaignAddress) {
        // --- Input Validation ---
        require(_resolveTimestamp > block.timestamp, "MarketFactory: Resolve timestamp must be in the future");
        require(_participationDeadline < _resolveTimestamp, "MarketFactory: Participation deadline must be before resolve timestamp");
        require(_minStake > 0, "MarketFactory: Minimum stake must be greater than zero");
        require(_ftsOracleAdapter != address(0), "MarketFactory: Oracle adapter address cannot be zero");
        require(_highBetTokenMaxSupply > 0, "MarketFactory: High token max supply must be greater than zero");
        require(_lowBetTokenMaxSupply > 0, "MarketFactory: Low token max supply must be greater than zero");

        // --- Deployment ---

        // 1) Deploy the optimized pool contract FIRST
        CryptoPool pool = new CryptoPool();

        // 2) Get the address of the newly deployed pool
        campaignAddress = address(pool);

        // 3) Deploy the two BetTokens, setting the POOL as the minter
        string memory highName   = string(abi.encodePacked("HighBet-", _cryptoTargated)); // Added '-' for clarity
        string memory highSymbol = string(abi.encodePacked("HIGH-", _cryptoTargated)); // Added '-' for clarity
        BaseBetToken highToken = new BaseBetToken(
            highName,
            highSymbol,
            _highBetTokenMaxSupply,
            campaignAddress // Pass pool address as minter
        );

        string memory lowName   = string(abi.encodePacked("LowBet-", _cryptoTargated)); // Added '-' for clarity
        string memory lowSymbol = string(abi.encodePacked("LOW-", _cryptoTargated)); // Added '-' for clarity
        BaseBetToken lowToken = new BaseBetToken(
            lowName,
            lowSymbol,
            _lowBetTokenMaxSupply,
            campaignAddress // Pass pool address as minter
        );

        // 4) Initialize the pool contract with its configuration and token addresses
        //    Note: The caller of initialize() is the MarketFactory (msg.sender inside initialize)
        //    Therefore, the MarketFactory becomes the owner of the CryptoPool.
        pool.initialize(
            _predictAmount,
            _cryptoTargated,
            _ftsOracleAdapter,
            _resolveTimestamp,
            _participationDeadline,
            _minStake,
            address(highToken),
            address(lowToken)
        );

        // --- Event Emission ---
        emit CryptoCampaignDeployed(
            campaignAddress,        // The address of the deployed pool
            msg.sender,             // The address that called this factory function (the factory owner)
            _cryptoTargated,        // The crypto symbol being predicted (matches event param 'question')
            _ftsOracleAdapter,      // Oracle adapter used
            _resolveTimestamp       // Resolution time
        );

        // campaignAddress is implicitly returned
    }

    // Potentially other functions for different market types or management...
}