pragma solidity 0.8.10;

import "@oz/token/ERC20/IERC20.sol";
import "@oz-up/access/OwnableUpgradeable.sol";
import "@oz-up/security/ReentrancyGuardUpgradeable.sol";

import "./lib/IExchange.sol";
import "./lib/ISortedOracles.sol";
import "./lib/IMentoReserve.sol";
import "./lib/IStableToken.sol";
import "./lib/FixidityLib.sol";
import "./lib/Freezable.sol";
import "./lib/UsingRegistry.sol";
import "./lib/ICeloVersionedContract.sol";

/**
 * @title Contract that allows to exchange StableToken for GoldToken and vice versa
 * using a Constant Product Market Maker Model
 */
contract Exchange is
    //   IExchange, // TODO FIX
    ICeloVersionedContract,
    OwnableUpgradeable,
    UsingRegistry,
    ReentrancyGuardUpgradeable,
    Freezable
{
    using FixidityLib for FixidityLib.Fraction;

    event Exchanged(address indexed exchanger, uint256 sellAmount, uint256 buyAmount, bool soldGold);
    event UpdateFrequencySet(uint256 updateFrequency);
    event MinimumReportsSet(uint256 minimumReports);
    event StableTokenSet(address indexed stable);
    event SpreadSet(uint256 spread);
    event ReserveFractionSet(uint256 reserveFraction);
    event BucketsUpdated(uint256 goldBucket, uint256 stableBucket);

    FixidityLib.Fraction public spread;

    // Fraction of the Reserve that is committed to the gold bucket when updating
    // buckets.
    FixidityLib.Fraction public reserveFraction;

    address public stable;

    // Size of the Uniswap gold bucket
    uint256 public goldBucket;
    // Size of the Uniswap stable token bucket
    uint256 public stableBucket;

    uint256 public lastBucketUpdate = 0;
    uint256 public updateFrequency;
    uint256 public minimumReports;

    bytes32 public stableTokenRegistryId;

    modifier updateBucketsIfNecessary() {
        _updateBucketsIfNecessary();
        _;
    }

    /**
     * @notice Returns the storage, major, minor, and patch version of the contract.
     * @return Storage version of the contract.
     * @return Major version of the contract.
     * @return Minor version of the contract.
     * @return Patch version of the contract.
     */
    function getVersionNumber() external pure returns (uint256, uint256, uint256, uint256) {
        return (1, 2, 0, 0);
    }

    /**
     * @notice Sets initialized == true on implementation contracts
     * @param isImplementation Set to true to lock he initialization
     */
    constructor(bool isImplementation) {
        if (isImplementation) _disableInitializers();
    }

    /**
     * @notice Used in place of the constructor to allow the contract to be upgradable via proxy.
     * @param registryAddress The address of the registry core smart contract.
     * @param stableTokenIdentifier String identifier of stabletoken in registry
     * @param _spread Spread charged on exchanges
     * @param _reserveFraction Fraction to commit to the gold bucket
     * @param _updateFrequency The time period that needs to elapse between bucket
     * updates
     * @param _minimumReports The minimum number of fresh reports that need to be
     * present in the oracle to update buckets
     * commit to the gold bucket
     */
    function initialize(
        address registryAddress,
        string calldata stableTokenIdentifier,
        uint256 _spread,
        uint256 _reserveFraction,
        uint256 _updateFrequency,
        uint256 _minimumReports
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        setRegistry(registryAddress);
        stableTokenRegistryId = keccak256(abi.encodePacked(stableTokenIdentifier));
        setSpread(_spread);
        setReserveFraction(_reserveFraction);
        setUpdateFrequency(_updateFrequency);
        setMinimumReports(_minimumReports);
    }

    /**
     * @notice Ensures stable token address is set in storage and initializes buckets.
     * @dev Will revert if stable token is not registered or does not have oracle reports.
     */
    function activateStable() external onlyOwner {
        require(stable == address(0), "StableToken address already activated");
        _setStableToken(registry.getAddressForOrDie(stableTokenRegistryId));
        _updateBucketsIfNecessary();
    }

    /**
     * @notice Exchanges a specific amount of one token for an unspecified amount
     * (greater than a threshold) of another.
     * @param from The address representing the message sender
     * @param sellAmount The number of tokens to send to the exchange.
     * @param minBuyAmount The minimum number of tokens for the exchange to send in return.
     * @param sellGold True if the caller is sending CELO to the exchange, false otherwise.
     * @return The number of tokens sent by the exchange.
     * @dev The caller must first have approved `sellAmount` to the exchange.
     * @dev This function can be frozen via the Freezable interface.
     */
    function sell(address from, uint256 sellAmount, uint256 minBuyAmount, bool sellGold)
        public
        onlyWhenNotFrozen
        onlyOwner
        updateBucketsIfNecessary
        nonReentrant
        returns (uint256)
    {
        // Function can be used to trade in two ways:
        // - kCUR -> kG: sellGold=false
        // - kG -> kCUR: sellGold=true
        (uint256 buyTokenBucket, uint256 sellTokenBucket) = _getBuyAndSellBuckets(sellGold);

        // amount of token that will be bought for the sellAmount. Must be bigger than
        uint256 buyAmount = _getBuyTokenAmount(buyTokenBucket, sellTokenBucket, sellAmount);

        require(buyAmount >= minBuyAmount, "Calculated buyAmount was less than specified minBuyAmount");

        _exchange(from, sellAmount, buyAmount, sellGold);
        return buyAmount;
    }

    /**
     * @dev DEPRECATED - Use `buy` or `sell`.
     * @notice Exchanges a specific amount of one token for an unspecified amount
     * (greater than a threshold) of another.
     * @param from The address representing the message sender
     * @param sellAmount The number of tokens to send to the exchange.
     * @param minBuyAmount The minimum number of tokens for the exchange to send in return.
     * @param sellGold True if the caller is sending CELO to the exchange, false otherwise.
     * @return The number of tokens sent by the exchange.
     * @dev The caller must first have approved `sellAmount` to the exchange.
     * @dev This function can be frozen via the Freezable interface.
     */
    function exchange(address from, uint256 sellAmount, uint256 minBuyAmount, bool sellGold)
        external
        returns (uint256)
    {
        return sell(from, sellAmount, minBuyAmount, sellGold);
    }

    /**
     * @notice Exchanges an unspecified amount (up to a threshold) of one token for
     * a specific amount of another.
     * @param from The address representing the message sender
     * @param buyAmount The number of tokens for the exchange to send in return.
     * @param maxSellAmount The maximum number of tokens to send to the exchange.
     * @param buyGold True if the exchange is sending CELO to the caller, false otherwise.
     * @return The number of tokens sent to the exchange.
     * @dev The caller must first have approved `maxSellAmount` to the exchange.
     * @dev This function can be frozen via the Freezable interface.
     */
    function buy(address from, uint256 buyAmount, uint256 maxSellAmount, bool buyGold)
        external
        onlyWhenNotFrozen
        onlyOwner
        updateBucketsIfNecessary
        nonReentrant
        returns (uint256)
    {
        // Function can be used to trade in two ways:
        // - kCUR -> kG: sellGold=false
        // - kG -> kCUR: sellGold=true
        bool sellGold = !buyGold;
        // Get current kCUR and kG buckets. These are calculated through the kCUR supply and querying the oracle for the ratio
        (uint256 buyTokenBucket, uint256 sellTokenBucket) = _getBuyAndSellBuckets(sellGold);

        // amount of token that need to be sold to receive the buy amount
        uint256 sellAmount = _getSellTokenAmount(buyTokenBucket, sellTokenBucket, buyAmount);

        require(sellAmount <= maxSellAmount, "Calculated sellAmount was greater than specified maxSellAmount");
        _exchange(from, sellAmount, buyAmount, sellGold);
        return sellAmount;
    }

    /**
     * @notice Exchanges a specific amount of one token for a specific amount of another.
     * @param from The address representing the message sender
     * @param sellAmount The number of tokens to send to the exchange.
     * @param buyAmount The number of tokens for the exchange to send in return.
     * @param sellGold True if the from address is sending CELO to the exchange, false otherwise.
     */
    function _exchange(address from, uint256 sellAmount, uint256 buyAmount, bool sellGold) private {
        IMentoReserve reserve = IMentoReserve(registry.getAddressForOrDie(RESERVE_REGISTRY_ID));
        // Trade kCUR -> kG, i.e. kCUR is swapped in and kG returned
        if (sellGold) {
            goldBucket += sellAmount;
            stableBucket -= buyAmount;

            // Transfer kCUR from -> reserver, for sell amount
            require(getGoldToken().transferFrom(from, address(reserve), sellAmount), "Transfer of sell token failed");
            // Mint kG -> from address, for buy amount
            require(IStableToken(stable).mint(from, buyAmount), "Mint of stable token failed");
        } else {
            // Trade kG -> kCUR, i.e. kG is swapped in and kCUR returned
            stableBucket += sellAmount;
            goldBucket -= buyAmount;

            // Transfer kG from -> reserver, for sell amount
            require(IERC20(stable).transferFrom(from, address(this), sellAmount), "Transfer of sell token failed");
            // Burn the kG token, for sell amount
            IStableToken(stable).burn(sellAmount);
            // Transfer kCUR from Reserve -> from, for buy amount
            require(reserve.transferExchangeGold(payable(from), buyAmount), "Transfer of buyToken failed");
        }

        emit Exchanged(from, sellAmount, buyAmount, sellGold);
    }

    /**
     * @notice Returns the amount of buy tokens a user would get for sellAmount of the sell token.
     * @param sellAmount The amount of sellToken the user is selling to the exchange.
     * @param sellGold `true` if gold is the sell token.
     * @return The corresponding buyToken amount.
     */
    function getBuyTokenAmount(uint256 sellAmount, bool sellGold) external view returns (uint256) {
        (uint256 buyTokenBucket, uint256 sellTokenBucket) = getBuyAndSellBuckets(sellGold);
        return _getBuyTokenAmount(buyTokenBucket, sellTokenBucket, sellAmount);
    }

    /**
     * @notice Returns the amount of sell tokens a user would need to exchange to receive buyAmount of
     * buy tokens.
     * @param buyAmount The amount of buyToken the user would like to purchase.
     * @param sellGold `true` if gold is the sell token.
     * @return The corresponding sellToken amount.
     */
    function getSellTokenAmount(uint256 buyAmount, bool sellGold) external view returns (uint256) {
        (uint256 buyTokenBucket, uint256 sellTokenBucket) = getBuyAndSellBuckets(sellGold);
        return _getSellTokenAmount(buyTokenBucket, sellTokenBucket, buyAmount);
    }

    /**
     * @notice Returns the buy token and sell token bucket sizes, in order. The ratio of
     * the two also represents the exchange rate between the two.
     * @param sellGold `true` if gold is the sell token.
     * @return buyTokenBucket
     * @return sellTokenBucket
     */
    function getBuyAndSellBuckets(bool sellGold) public view returns (uint256, uint256) {
        uint256 currentGoldBucket = goldBucket;
        uint256 currentStableBucket = stableBucket;

        if (shouldUpdateBuckets()) {
            (currentGoldBucket, currentStableBucket) = getUpdatedBuckets();
        }

        if (sellGold) {
            return (currentStableBucket, currentGoldBucket);
        } else {
            return (currentGoldBucket, currentStableBucket);
        }
    }

    /**
     * @notice Allows owner to set the update frequency
     * @param newUpdateFrequency The new update frequency
     */
    function setUpdateFrequency(uint256 newUpdateFrequency) public onlyOwner {
        updateFrequency = newUpdateFrequency;
        emit UpdateFrequencySet(newUpdateFrequency);
    }

    /**
     * @notice Allows owner to set the minimum number of reports required
     * @param newMininumReports The new update minimum number of reports required
     */
    function setMinimumReports(uint256 newMininumReports) public onlyOwner {
        minimumReports = newMininumReports;
        emit MinimumReportsSet(newMininumReports);
    }

    /**
     * @notice Allows owner to set the Stable Token address
     * @param newStableToken The new address for Stable Token
     */
    function setStableToken(address newStableToken) public onlyOwner {
        _setStableToken(newStableToken);
    }

    /**
     * @notice Allows owner to set the spread
     * @param newSpread The new value for the spread
     */
    function setSpread(uint256 newSpread) public onlyOwner {
        spread = FixidityLib.wrap(newSpread);
        require(FixidityLib.lte(spread, FixidityLib.fixed1()), "Spread must be less than or equal to 1");
        emit SpreadSet(newSpread);
    }

    /**
     * @notice Allows owner to set the Reserve Fraction
     * @param newReserveFraction The new value for the reserve fraction
     */
    function setReserveFraction(uint256 newReserveFraction) public onlyOwner {
        reserveFraction = FixidityLib.wrap(newReserveFraction);
        require(reserveFraction.lt(FixidityLib.fixed1()), "reserve fraction must be smaller than 1");
        emit ReserveFractionSet(newReserveFraction);
    }

    function _setStableToken(address newStableToken) internal {
        stable = newStableToken;
        emit StableTokenSet(newStableToken);
    }

    /**
     * @notice Returns the buy token and sell token bucket sizes, in order. The ratio of
     * the two also represents the exchange rate between the two.
     * @param sellGold `true` if gold is the sell token.
     * @return buyTokenBucket
     * @return sellTokenBucket
     */
    function _getBuyAndSellBuckets(bool sellGold) private view returns (uint256, uint256) {
        if (sellGold) {
            return (stableBucket, goldBucket);
        } else {
            return (goldBucket, stableBucket);
        }
    }

    /**
     * @dev Returns the amount of buy tokens a user would get for sellAmount of the sell.
     * @param buyTokenBucket The buy token bucket size.
     * @param sellTokenBucket The sell token bucket size.
     * @param sellAmount The amount the user is selling to the exchange.
     * @return The corresponding buy amount.
     */
    function _getBuyTokenAmount(uint256 buyTokenBucket, uint256 sellTokenBucket, uint256 sellAmount)
        private
        view
        returns (uint256)
    {
        if (sellAmount == 0) return 0;

        FixidityLib.Fraction memory reducedSellAmount = getReducedSellAmount(sellAmount);
        FixidityLib.Fraction memory numerator = reducedSellAmount.multiply(FixidityLib.newFixed(buyTokenBucket));
        FixidityLib.Fraction memory denominator = FixidityLib.newFixed(sellTokenBucket).add(reducedSellAmount);

        // Can't use FixidityLib.divide because denominator can easily be greater
        // than maxFixedDivisor.
        // Fortunately, we expect an integer result, so integer division gives us as
        // much precision as we could hope for.
        return numerator.unwrap() / denominator.unwrap();
    }

    /**
     * @notice Returns the amount of sell tokens a user would need to exchange to receive buyAmount of
     * buy tokens.
     * @param buyTokenBucket The buy token bucket size.
     * @param sellTokenBucket The sell token bucket size.
     * @param buyAmount The amount the user is buying from the exchange.
     * @return The corresponding sell amount.
     */
    function _getSellTokenAmount(uint256 buyTokenBucket, uint256 sellTokenBucket, uint256 buyAmount)
        private
        view
        returns (uint256)
    {
        if (buyAmount == 0) return 0;

        FixidityLib.Fraction memory numerator = FixidityLib.newFixed(buyAmount * sellTokenBucket);
        FixidityLib.Fraction memory denominator =
            FixidityLib.newFixed(buyTokenBucket - buyAmount).multiply(FixidityLib.fixed1().subtract(spread));

        // See comment in _getBuyTokenAmount
        return numerator.unwrap() / denominator.unwrap();
    }

    /**
     * @return buyTokenBucket
     * @return sellTokenBucket
     */
    function getUpdatedBuckets() private view returns (uint256, uint256) {
        uint256 updatedGoldBucket = getUpdatedGoldBucket();
        uint256 exchangeRateNumerator;
        uint256 exchangeRateDenominator;
        (exchangeRateNumerator, exchangeRateDenominator) = getOracleExchangeRate();
        uint256 updatedStableBucket = exchangeRateNumerator * updatedGoldBucket / exchangeRateDenominator;
        return (updatedGoldBucket, updatedStableBucket);
    }

    function getUpdatedGoldBucket() private view returns (uint256) {
        uint256 reserveGoldBalance = getReserve().getUnfrozenReserveGoldBalance();
        return reserveFraction.multiply(FixidityLib.newFixed(reserveGoldBalance)).fromFixed();
    }

    /**
     * @notice If conditions are met, updates the Uniswap bucket sizes to track
     * the price reported by the Oracle.
     */
    function _updateBucketsIfNecessary() private {
        if (shouldUpdateBuckets()) {
            // solhint-disable-next-line not-rely-on-time
            lastBucketUpdate = block.timestamp;

            (goldBucket, stableBucket) = getUpdatedBuckets();
            emit BucketsUpdated(goldBucket, stableBucket);
        }
    }

    /**
     * @notice Calculates the sell amount reduced by the spread.
     * @param sellAmount The original sell amount.
     * @return The reduced sell amount, computed as (1 - spread) * sellAmount
     */
    function getReducedSellAmount(uint256 sellAmount) private view returns (FixidityLib.Fraction memory) {
        return FixidityLib.fixed1().subtract(spread).multiply(FixidityLib.newFixed(sellAmount));
    }

    /**
     * @notice Checks conditions required for bucket updates.
     * @return The Rate numerator - whether or not buckets should be updated.
     *         The rate denominator - whether or not buckets should be updated.
     */
    function shouldUpdateBuckets() private view returns (bool) {
        ISortedOracles sortedOracles = ISortedOracles(registry.getAddressForOrDie(SORTED_ORACLES_REGISTRY_ID));
        (bool isReportExpired,) = sortedOracles.isOldestReportExpired(stable);
        // solhint-disable-next-line not-rely-on-time
        bool timePassed = block.timestamp >= lastBucketUpdate + updateFrequency;
        bool enoughReports = sortedOracles.numRates(stable) >= minimumReports;
        // solhint-disable-next-line not-rely-on-time
        bool medianReportRecent = sortedOracles.medianTimestamp(stable) > block.timestamp - updateFrequency;
        return timePassed && enoughReports && medianReportRecent && !isReportExpired;
    }

    function getOracleExchangeRate() private view returns (uint256, uint256) {
        uint256 rateNumerator;
        uint256 rateDenominator;
        (rateNumerator, rateDenominator) =
            ISortedOracles(registry.getAddressForOrDie(SORTED_ORACLES_REGISTRY_ID)).medianRate(stable);
        require(rateDenominator > 0, "exchange rate denominator must be greater than 0");
        return (rateNumerator, rateDenominator);
    }
}
