// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BaseBetToken } from "./BetTokens/BaseBetToken.sol";
import { IBetToken } from "./interface/IBetToken.sol";


interface IMarketPoolCrypto {
    event Predicted(address indexed user, bool prediction, uint224 amount);
    event Resolved(bool greaterThan, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 userReward, uint256 protocolReward);
    event HighBetTokenAwarded(address indexed user, uint256 amount);
    event LowBetTokenAwarded(address indexed user, uint256 amount);
    event HighBetTokenDeployed(address indexed tokenAddress, uint256 maxSupply);
    event LowBetTokenDeployed(address indexed tokenAddress, uint256 maxSupply);

    function initialize(
        uint256 _predictAmount,
        string memory _cryptoTargated,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        uint256 _highBetTokenMaxSupply,
        uint256 _lowBetTokenMaxSupply,
        address _protocolTreasury
    ) external;
}

interface IFtsoV2PriceFeed {
    function getPriceFeed(string memory _symbol)
        external
        view
        returns (uint256 _price, int8 _decimals, uint64 _timestamp);
}

// Assuming HighBetToken and LowBetToken inherit from BaseBetToken and are defined/imported
contract HighBetToken is BaseBetToken {
    constructor(string memory _name, string memory _symbol, uint256 _maxSupply, address _minter)
        BaseBetToken(_name, _symbol, _maxSupply, _minter)
    {}
}

contract LowBetToken is BaseBetToken {
     constructor(string memory _name, string memory _symbol, uint256 _maxSupply, address _minter)
        BaseBetToken(_name, _symbol, _maxSupply, _minter)
    {}
}

contract CryptoMarketPool is IMarketPoolCrypto, ReentrancyGuard {
        uint256 private predictAmount;
    string  private cryptoTargated;
    address private oracleAdapter;
    uint256 private resolveTimestamp;
    uint256 private participationDeadline;
    uint256 private minStake;
    bool    private initialized;
    bool    private resolved;
    bool    private greaterThan;

    uint256 public forGreaterThan = 0;
    uint256 public againstGreaterThan = 0;
    uint256 public stakeForGreaterThan = 0;
    uint256 public totalStake = 0;

    uint8 public constant PRECISION = 18;
    uint256 public constant STALE_PRICE_THRESHOLD = 300;
    uint256 public constant FEE_PERCENTAGE = 2;
    uint256 public globalFee;

    IFtsoV2PriceFeed public ftsoV2;

    mapping(address => bool) public rewardClaimed;
    mapping(address => bool) public betOn;
    mapping(address => uint256) public amountStaked;

    IBetToken public highBetToken;
    IBetToken public lowBetToken;

    address public protocolTreasury;

    modifier onlyInitialized() {
        require(initialized, "Contract not initialized");
        _;
    }

    function initialize(
        uint256 _predictAmount,
        string memory _cryptoTargated,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        uint256 _highBetTokenMaxSupply,
        uint256 _lowBetTokenMaxSupply,
        address _protocolTreasury
    ) external override {
        require(!initialized, "Contract already initialized");
        require(_oracleAdapter != address(0), "Invalid oracle address");
        require(_participationDeadline < _resolveTimestamp, "Deadline must be before resolution");
        require(_protocolTreasury != address(0), "Protocol treasury cannot be zero");

        predictAmount = _predictAmount;
        cryptoTargated = _cryptoTargated;
        oracleAdapter = _oracleAdapter;
        resolveTimestamp = _resolveTimestamp;
        participationDeadline = _participationDeadline;
        minStake = _minStake;
        protocolTreasury = _protocolTreasury;
        initialized = true;
        ftsoV2 = IFtsoV2PriceFeed(_oracleAdapter);

        string memory highName = string(abi.encodePacked("HighBet", _cryptoTargated));
        string memory highSymbol = string(abi.encodePacked("HIGH", _cryptoTargated));
        address highTokenAddress = address(new HighBetToken(highName, highSymbol, _highBetTokenMaxSupply, address(this)));
        highBetToken = IBetToken(highTokenAddress);

        string memory lowName = string(abi.encodePacked("LowBet", _cryptoTargated));
        string memory lowSymbol = string(abi.encodePacked("LOW", _cryptoTargated));
        address lowTokenAddress = address(new LowBetToken(lowName, lowSymbol, _lowBetTokenMaxSupply, address(this)));
        lowBetToken = IBetToken(lowTokenAddress);

        emit HighBetTokenDeployed(highTokenAddress, _highBetTokenMaxSupply);
        emit LowBetTokenDeployed(lowTokenAddress, _lowBetTokenMaxSupply);
    }

    function predict(
        bool _prediction,
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
        totalStake += _stakeAmount;

        emit Predicted(msg.sender, _prediction, uint224(msg.value));

        uint256 tokensToAward = _stakeAmount;

        if (tokensToAward > 0) {
            if (_prediction) {
                uint256 currentSupply = highBetToken.totalSupply();
                uint256 maxSupply = highBetToken.MAX_SUPPLY();

                require(currentSupply + tokensToAward <= maxSupply, "Cannot place bet: HighBetToken maximum supply reached");

                try highBetToken.mint(msg.sender, tokensToAward) {
                    emit HighBetTokenAwarded(msg.sender, tokensToAward);
                } catch (bytes memory reason) {
                     revert(string(abi.encodePacked("HighBetToken minting failed: ", reason)));
                }

            } else {
                uint256 currentSupply = lowBetToken.totalSupply();
                uint256 maxSupply = lowBetToken.MAX_SUPPLY();

                require(currentSupply + tokensToAward <= maxSupply, "Cannot place bet: LowBetToken maximum supply reached");

                try lowBetToken.mint(msg.sender, tokensToAward) {
                    emit LowBetTokenAwarded(msg.sender, tokensToAward);
                } catch (bytes memory reason) {
                     revert(string(abi.encodePacked("LowBetToken minting failed: ", reason)));
                }
            }
        }
    }

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
        uint256 totalWinningStakeNative;
        if (greaterThan) {
            totalLosingStake = totalStake - stakeForGreaterThan;
            totalWinningStakeNative = stakeForGreaterThan;
        } else {
            totalLosingStake = stakeForGreaterThan;
            totalWinningStakeNative = totalStake - stakeForGreaterThan;
        }
        globalFee = (totalLosingStake * FEE_PERCENTAGE) / 100;

        resolved = true;
        emit Resolved(greaterThan, block.timestamp);
    }

    function claimRewards() external onlyInitialized nonReentrant {
        require(resolved, "Campaign not yet resolved");

         IBetToken winningBetToken;

         uint256 userWinningTokenBalance = winningBetToken.balanceOf(msg.sender);

        require(userWinningTokenBalance > 0, "No winning tokens held or already claimed");

        require(!rewardClaimed[msg.sender], "Reward already claimed");

       

        if (greaterThan) {
            winningBetToken = highBetToken;
        } else {
            winningBetToken = lowBetToken;
        }

       

        uint256 totalWinningTokenSupply = winningBetToken.totalSupply();
        require(totalWinningTokenSupply > 0, "Internal error: No winning tokens exist");

        uint256 distributablePool = totalStake > globalFee ? totalStake - globalFee : 0;

        uint256 totalUserNativeReward = (uint256(userWinningTokenBalance) * distributablePool) / totalWinningTokenSupply;

        require(totalUserNativeReward > 0, "Calculated reward is zero");
        require(distributablePool >= totalUserNativeReward, "Internal error: payout exceeds distributable pool");

        uint256 userReward = (totalUserNativeReward * 90) / 100;
        uint256 protocolReward = totalUserNativeReward - userReward;

        require(address(this).balance >= userReward + protocolReward, "Insufficient contract balance for transfers");

        try winningBetToken.burn(msg.sender, userWinningTokenBalance) {
             // Token burn successful
        } catch (bytes memory reason) {
             revert(string(abi.encodePacked("Winning BetToken burn failed: ", reason)));
        }

        (bool sentUser, ) = payable(msg.sender).call{value: userReward}("");
        require(sentUser, "Native token transfer to user failed");

        (bool sentProtocol, ) = payable(protocolTreasury).call{value: protocolReward}("");
        require(sentProtocol, "Native token transfer to protocol failed");

        rewardClaimed[msg.sender] = true;

        emit RewardClaimed(msg.sender, userReward, protocolReward);
    }

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
             require(diff < 78, "Scale multiplication overflow");
             return price * (10 ** diff);
         } else {
             uint8 diff = uint8(priceDecimals - int8(targetDecimals));
              require(diff < 78, "Scale division overflow");
             return price / (10 ** diff);
         }
     }
}