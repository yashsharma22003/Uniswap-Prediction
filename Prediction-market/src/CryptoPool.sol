// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Interfaces
interface IBetToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function MAX_SUPPLY() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IFtsoV2PriceFeed {
    function getPriceFeed(string memory _symbol)
        external
        view
        returns (uint256 _price, int8 _decimals, uint64 _timestamp);
}

interface IMarketPoolCrypto {
    event Predicted(address indexed user, bool prediction, uint256 amount);
    event Resolved(bool greaterThan, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 amount);
    event HighBetTokenAwarded(address indexed user, uint256 amount);
    event LowBetTokenAwarded(address indexed user, uint256 amount);

    function initialize(
        uint256 _predictAmount,
        string memory _cryptoTargated,
        address _oracleAdapter,
        uint256 _resolveTimestamp,
        uint256 _participationDeadline,
        uint256 _minStake,
        address _highBetTokenAddress,
        address _lowBetTokenAddress
    ) external;
}

// Optimized Market Pool
contract CryptoPool is IMarketPoolCrypto, ReentrancyGuard {
    // --- Errors (custom, saves bytecode) ---
    error NotInit();
    error AlreadyInit();
    error DeadlinePassed();
    error BelowMinStake();
    error AmountMismatch();
    error MaxSupplyReached();
    error ResolveTooEarly();
    error AlreadyResolved();
    error StalePrice();
    error NoWinningStake();
    error NoStake();
    error RewardAlreadyClaimed();
    error NotOwner();
    error TransferFailed();
    error ScaleOverflow();

    // --- Packed Storage ---
    uint256 private _predictAmount;
    uint256 private _resolveTimestamp;
    uint256 private _participationDeadline;
    uint256 private _minStake;
    address private _oracleAdapter;
    // flags: bit0=initialized, bit1=resolved, bit2=greaterThan
    uint8   private _flags;
    string  private _cryptoTargated;

    uint128 private _forCount;
    uint128 private _againstCount;
    uint256 private _stakeForGreaterThan;
    uint256 private _totalStake;

    uint256 private _globalFee;
    address private _owner;

    IFtsoV2PriceFeed private _ftsoV2;
    IBetToken private _highBetToken;
    IBetToken private _lowBetToken;

    struct Bet { bool greaterThan; uint256 stake; }
    mapping(address => Bet) private _bets;
    mapping(address => bool) private _rewardClaimed;

    uint8 public constant PRECISION = 18;
    uint256 public constant STALE_PRICE_THRESHOLD = 300;
    uint256 public constant FEE_PERCENTAGE = 2;

    modifier onlyInitialized() {
        if ((_flags & 1) == 0) revert NotInit();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    // --- Initialize ---
    function initialize(
        uint256 predictAmount_,
        string memory cryptoTargated_,
        address oracleAdapter_,
        uint256 resolveTimestamp_,
        uint256 participationDeadline_,
        uint256 minStake_,
        address highBetTokenAddress_,
        address lowBetTokenAddress_
    ) external override {
        if ((_flags & 1) != 0) revert AlreadyInit();
        if (oracleAdapter_ == address(0)) revert NotInit();
        if (participationDeadline_ >= resolveTimestamp_) revert DeadlinePassed();
        _predictAmount = predictAmount_;
        _cryptoTargated = cryptoTargated_;
        _oracleAdapter = oracleAdapter_;
        _ftsoV2 = IFtsoV2PriceFeed(oracleAdapter_);
        _resolveTimestamp = resolveTimestamp_;
        _participationDeadline = participationDeadline_;
        _minStake = minStake_;
        _highBetToken = IBetToken(highBetTokenAddress_);
        _lowBetToken = IBetToken(lowBetTokenAddress_);
        _owner = msg.sender;
        _flags |= 1; // initialized
    }

    // --- Predict/Bet ---
    function predict(bool prediction, uint256 stakeAmount) external payable onlyInitialized nonReentrant {
        if (block.timestamp >= _participationDeadline) revert DeadlinePassed();
        if ((_flags & 2) != 0) revert AlreadyResolved();
        if (msg.value < _minStake) revert BelowMinStake();
        if (msg.value != stakeAmount) revert AmountMismatch();

        Bet storage b = _bets[msg.sender];
        if (b.stake > 0) {
            _totalStake -= b.stake;
            if (b.greaterThan) {
                _stakeForGreaterThan -= b.stake;
                _forCount--;
            } else {
                _againstCount--;
            }
        }
        b.greaterThan = prediction;
        b.stake = stakeAmount;
        _totalStake += stakeAmount;
        if (prediction) {
            _forCount++;
            _stakeForGreaterThan += stakeAmount;
        } else {
            _againstCount++;
        }
        emit Predicted(msg.sender, prediction, stakeAmount);

        IBetToken token = prediction ? _highBetToken : _lowBetToken;
        uint256 supply = token.totalSupply();
        uint256 max = token.MAX_SUPPLY();
        if (supply + stakeAmount > max) revert MaxSupplyReached();
        token.mint(msg.sender, stakeAmount);
        if (prediction) emit HighBetTokenAwarded(msg.sender, stakeAmount);
        else           emit LowBetTokenAwarded(msg.sender, stakeAmount);
    }

    // --- Resolve outcome ---
    function resolve() external onlyInitialized {
        if (block.timestamp < _resolveTimestamp) revert ResolveTooEarly();
        if ((_flags & 2) != 0) revert AlreadyResolved();

        (uint256 price, int8 dec, uint64 ts) = _ftsoV2.getPriceFeed(_cryptoTargated);
        if (block.timestamp - ts > STALE_PRICE_THRESHOLD) revert StalePrice();
        uint256 scaled = _scalePrice(price, dec, PRECISION);
        bool gt = scaled > _predictAmount;
        if (gt) _flags |= 4;
        _flags |= 2; // resolved

        uint256 losing = gt ? (_totalStake - _stakeForGreaterThan) : _stakeForGreaterThan;
        _globalFee = (losing * FEE_PERCENTAGE) / 100;
        emit Resolved(gt, block.timestamp);
    }

    // --- Claim rewards ---
    function claimRewards() external onlyInitialized nonReentrant {
        if ((_flags & 2) == 0) revert AlreadyResolved();
        Bet memory b = _bets[msg.sender];
        if (b.stake == 0) revert NoStake();
        if (_rewardClaimed[msg.sender]) revert RewardAlreadyClaimed();

        bool gtFlag = (_flags & 4) != 0;
        bool won = (b.greaterThan && gtFlag) || (!b.greaterThan && !gtFlag);
        _rewardClaimed[msg.sender] = true;
        if (!won) {
            emit RewardClaimed(msg.sender, 0);
            return;
        }

        uint256 winningStake = gtFlag ? _stakeForGreaterThan : (_totalStake - _stakeForGreaterThan);
        uint256 losingStake  = _totalStake - winningStake;
        uint256 pool = losingStake > _globalFee ? losingStake - _globalFee : 0;
        if (winningStake == 0) revert NoWinningStake();

        uint256 reward = b.stake + (b.stake * pool) / winningStake;
        (bool s, ) = payable(msg.sender).call{value: reward}("");
        if (!s) revert TransferFailed();
        emit RewardClaimed(msg.sender, reward);
    }

    // --- Owner withdraw fees ---
    function withdrawFees() external onlyOwner {
        uint256 amt = _globalFee;
        _globalFee = 0;
        (bool s, ) = payable(_owner).call{value: amt}("");
        if (!s) revert TransferFailed();
    }

    // --- Batch Getters ---
    function getConfig()
        external view
        returns(
            uint256 predictAmount_,
            string memory cryptoTargated_,
            address oracleAdapter_,
            uint256 resolveTimestamp_,
            uint256 participationDeadline_,
            uint256 minStake_,
            bool initialized_,
            bool resolved_,
            bool greaterThan_,
            uint256 globalFee_
        )
    {
        predictAmount_        = _predictAmount;
        cryptoTargated_       = _cryptoTargated;
        oracleAdapter_        = _oracleAdapter;
        resolveTimestamp_     = _resolveTimestamp;
        participationDeadline_ = _participationDeadline;
        minStake_             = _minStake;
        initialized_          = (_flags & 1) != 0;
        resolved_             = (_flags & 2) != 0;
        greaterThan_          = (_flags & 4) != 0;
        globalFee_            = _globalFee;
    }

    function getStats(address user)
        external view
        returns(
            bool userBetGreaterThan_,
            uint256 userStake_,
            uint128 totalFor_,
            uint128 totalAgainst_,
            uint256 stakeFor_,
            uint256 stakeAgainst_
        )
    {
        Bet storage b = _bets[user];
        userBetGreaterThan_ = b.greaterThan;
        userStake_          = b.stake;
        totalFor_           = _forCount;
        totalAgainst_       = _againstCount;
        stakeFor_           = _stakeForGreaterThan;
        stakeAgainst_       = _totalStake - _stakeForGreaterThan;
    }

    function getTokens()
        external view
        returns(
            address highAddr_, uint256 highTotal_, uint256 highMax_,
            address lowAddr_,  uint256 lowTotal_,  uint256 lowMax_
        )
    {
        highAddr_  = address(_highBetToken);
        highTotal_ = _highBetToken.totalSupply();
        highMax_   = _highBetToken.MAX_SUPPLY();
        lowAddr_   = address(_lowBetToken);
        lowTotal_  = _lowBetToken.totalSupply();
        lowMax_    = _lowBetToken.MAX_SUPPLY();
    }

    // --- Price scaling ---
    function _scalePrice(uint256 price, int8 pDec, uint8 tDec) internal pure returns (uint256) {
        if (pDec == int8(tDec)) return price;
        if (pDec < int8(tDec)) {
            uint8 diff = uint8(int8(tDec) - pDec);
            if (diff >= 78) revert ScaleOverflow();
            return price * (10 ** diff);
        } else {
            uint8 diff = uint8(pDec - int8(tDec));
            if (diff >= 78) revert ScaleOverflow();
            return price / (10 ** diff);
        }
    }
}
