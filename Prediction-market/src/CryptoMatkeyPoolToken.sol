// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // Keep original pragma

// --- Interface for a generic BetToken (can be used for both High and Low) ---
interface IBetToken {
    function mint(address to, uint256 amount) external;
    function MAX_SUPPLY() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

// Modify the main interface
interface IMarketPoolCrypto {
    // Removed betTokenAwarded from Predicted event
    event Predicted(address indexed user, bool prediction, uint256 amount);
    event Resolved(bool greaterThan, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 amount);
    // NEW Events for specific token awards
    event HighBetTokenAwarded(address indexed user, uint256 amount);
    event LowBetTokenAwarded(address indexed user, uint256 amount);


    // Modify initialize interface to accept both token addresses
    function initialize(
        uint256 _predictAmount,
        string memory _cryptoTargated,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _rewardToken,         // Original reward token
        address _highBetTokenAddress, // NEW: High Bet Token address
        address _lowBetTokenAddress   // NEW: Low Bet Token address
    ) external;
}

// Assuming FtsoV2PriceFeed interface is correct
interface IFtsoV2PriceFeed {
    function getPriceFeed(string memory _symbol)
        external
        view
        returns (uint256 _price, int8 _decimals, uint64 _timestamp);
}

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// --- MODIFIED CONTRACT ---
contract CryptoMarketPool is IMarketPoolCrypto, ReentrancyGuard {
    // --- Existing State Variables ---
    uint256 public predictAmount;
    string public cryptoTargated;
    address public oracleAdapter;
    uint256 public resolveTimestamp;
    uint256 public participationDeadline;
    uint256 public minStake;
    address public rewardToken; // Original reward token address
    bool public initialized = false;
    bool public resolved = false;
    bool public greaterThan;

    uint256 public forGreaterThan = 0;
    uint256 public againstGreaterThan = 0;
    uint256 public stakeForGreaterThan = 0;
    uint256 public totalStake = 0;

    uint8 public constant PRECISION = 18;
    uint256 public constant STALE_PRICE_THRESHOLD = 300; // 5 minutes

    uint256 public constant FEE_PERCENTAGE = 2; // 2%
    uint256 public globalFee;

    IFtsoV2PriceFeed public ftsoV2;

    mapping(address => bool) public rewardClaimed;
    mapping(address => bool) public betOn;
    mapping(address => uint256) public amountStaked;
    mapping(address => Bet) public bets;

    struct Bet {
        address _beter;
        bool _greaterThanBet;
        uint256 _stake;
    }

    // --- NEW State Variables for TWO Bet Tokens ---
    IBetToken public highBetToken; // Instance for HighBetToken
    IBetToken public lowBetToken;  // Instance for LowBetToken

    // --- Modifiers ---
    modifier onlyInitialized() {
        require(initialized, "Contract not initialized");
        _;
    }

    // --- MODIFIED initialize Function ---
    function initialize(
        uint256 _predictAmount,
        string memory _cryptoTargated,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _rewardToken,          // Original reward token
        address _highBetTokenAddress,  // NEW: High Bet Token address
        address _lowBetTokenAddress    // NEW: Low Bet Token address
    ) external override {
        require(!initialized, "Contract already initialized");
        require(_oracleAdapter != address(0), "Invalid oracle address");
        require(_participationDeadline < _resolveTimestamp, "Deadline must be before resolution");
        require(_highBetTokenAddress != address(0), "Invalid HighBetToken address"); // NEW check
        require(_lowBetTokenAddress != address(0), "Invalid LowBetToken address");   // NEW check

        predictAmount = _predictAmount;
        cryptoTargated = _cryptoTargated;
        oracleAdapter = _oracleAdapter;
        resolveTimestamp = _resolveTimestamp;
        participationDeadline = _participationDeadline;
        minStake = _minStake;
        rewardToken = _rewardToken; // Store original reward token
        initialized = true;
        ftsoV2 = IFtsoV2PriceFeed(_oracleAdapter);

        // --- NEW: Store BOTH Bet Token instances ---
        highBetToken = IBetToken(_highBetTokenAddress);
        lowBetToken = IBetToken(_lowBetTokenAddress);
    }

    // --- MODIFIED predict Function ---
    function predict(
        bool _prediction, // true for High, false for Low
        uint256 _stakeAmount
    ) external payable onlyInitialized nonReentrant {
        require(
            block.timestamp < participationDeadline,
            "Participation deadline has passed"
        );
        require(!resolved, "Pool is resolving or resolved");
        require(msg.value >= minStake, "Staked amount is below minimum");
        require(
            msg.value == _stakeAmount,
            "Ether sent and amount passed mismatch"
        );

        // --- Existing stake update logic ---
        uint256 previousStake = amountStaked[msg.sender];
        if (previousStake > 0) {
            totalStake -= previousStake;
            if (betOn[msg.sender]) {
                stakeForGreaterThan -= previousStake;
                if (forGreaterThan > 0) --forGreaterThan;
            } else {
                if (againstGreaterThan > 0) --againstGreaterThan;
            }
        }

        if (_prediction) {
            ++forGreaterThan;
            stakeForGreaterThan += _stakeAmount;
        } else {
            ++againstGreaterThan;
        }
        betOn[msg.sender] = _prediction;
        amountStaked[msg.sender] = _stakeAmount;
        bets[msg.sender] = Bet(msg.sender, _prediction, _stakeAmount);
        totalStake += _stakeAmount;
        // --- End existing stake update logic ---

        // Emit the basic prediction event (without token info now)
        emit Predicted(msg.sender, _prediction, msg.value);

        // --- NEW: Award Specific Bet Tokens ---
        uint256 tokensToAward = 0;
        // Award ratio: 1 wei staked = 1 unit of the corresponding BetToken
        uint256 calculatedTokens = _stakeAmount;

        if (calculatedTokens > 0) {
            if (_prediction) {
                // --- Award HIGH Bet Token ---
                uint256 currentSupply = highBetToken.totalSupply();
                uint256 maxSupply = highBetToken.MAX_SUPPLY();

                if (currentSupply + calculatedTokens <= maxSupply) {
                    tokensToAward = calculatedTokens;
                    try highBetToken.mint(msg.sender, tokensToAward) {
                        emit HighBetTokenAwarded(msg.sender, tokensToAward);
                    } catch (bytes memory reason) {
                        revert(string(abi.encodePacked("HighBetToken minting failed: ", reason)));
                    }
                } else {
                    revert("Cannot place bet: HighBetToken maximum supply reached");
                }
            } else {
                // --- Award LOW Bet Token ---
                uint256 currentSupply = lowBetToken.totalSupply();
                uint256 maxSupply = lowBetToken.MAX_SUPPLY();

                if (currentSupply + calculatedTokens <= maxSupply) {
                    tokensToAward = calculatedTokens;
                    try lowBetToken.mint(msg.sender, tokensToAward) {
                        emit LowBetTokenAwarded(msg.sender, tokensToAward);
                    } catch (bytes memory reason) {
                        revert(string(abi.encodePacked("LowBetToken minting failed: ", reason)));
                    }
                } else {
                    revert("Cannot place bet: LowBetToken maximum supply reached");
                }
            }
        }
        // --- End Award Specific Bet Tokens ---
    }


    // --- resolve Function (Unchanged) ---
    function resolve() external onlyInitialized {
         require(
            block.timestamp >= resolveTimestamp,
            "Resolve timestamp not reached"
        );
        require(!resolved, "Pool already resolved");

        (uint256 price, int8 decimal, uint64 timestamp) = ftsoV2.getPriceFeed(
            cryptoTargated
        );

        require(
            block.timestamp - uint256(timestamp) <= STALE_PRICE_THRESHOLD,
            "Price data is stale"
        );

        uint256 priceCorrected = scalePrice(price, decimal, PRECISION);

        if (priceCorrected > predictAmount) {
            greaterThan = true;
        } else {
            greaterThan = false;
        }

        uint256 totalLosingStake;
        if (greaterThan) {
            totalLosingStake = totalStake - stakeForGreaterThan;
        } else {
            totalLosingStake = stakeForGreaterThan;
        }
        globalFee = (totalLosingStake * FEE_PERCENTAGE) / 100;

        resolved = true;
        emit Resolved(greaterThan, block.timestamp);
    }

    // --- claimRewards Function (Unchanged regarding Bet Tokens) ---
    function claimRewards() external onlyInitialized nonReentrant {
        require(resolved, "Campaign not yet resolved");
        require(amountStaked[msg.sender] > 0, "No stake found for user");
        require(!rewardClaimed[msg.sender], "Reward already claimed");

        if (betOn[msg.sender] != greaterThan) {
            rewardClaimed[msg.sender] = true;
            emit RewardClaimed(msg.sender, 0); // Emit 0 reward for loss
            return; // Exit function gracefully
        }

        uint256 userStake = amountStaked[msg.sender];
        uint256 totalWinningStake;
        uint256 totalLosingStake;

        if (greaterThan) {
            totalWinningStake = stakeForGreaterThan;
            totalLosingStake = totalStake - stakeForGreaterThan;
        } else {
            totalWinningStake = totalStake - stakeForGreaterThan;
            totalLosingStake = stakeForGreaterThan;
        }

        require(totalWinningStake > 0, "Internal error: No winning stake found");

        uint256 netLosingPool = totalLosingStake > globalFee
            ? totalLosingStake - globalFee
            : 0;

        uint256 reward = userStake + (userStake * netLosingPool) / totalWinningStake;

        rewardClaimed[msg.sender] = true;

        (bool sent, ) = payable(msg.sender).call{value: reward}("");
        require(sent, "Native token transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }

    // --- scalePrice Function (Unchanged, added require checks from thought process) ---
     function scalePrice(
        uint256 price,
        int8 priceDecimals,
        uint8 targetDecimals
    ) internal pure returns (uint256) {
         if (priceDecimals == int8(targetDecimals)) {
            return price;
        }
        if (priceDecimals < int8(targetDecimals)) {
            uint8 diff = uint8(int8(targetDecimals) - priceDecimals);
            require(diff < 78, "Scale multiplication overflow"); // Prevent overflow on 10**diff
            return price * (10 ** diff);
        } else { // priceDecimals > targetDecimals
            uint8 diff = uint8(priceDecimals - int8(targetDecimals));
             require(diff < 78, "Scale division overflow"); // Prevent overflow on 10**diff
            return price / (10 ** diff);
        }
    }

    // Optional fee withdrawal function (Unchanged)
    // ... add withdrawFees() here if needed ...
}