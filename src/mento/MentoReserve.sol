pragma solidity 0.8.10;

import "@oz/token/ERC20/IERC20.sol";
import "@oz-up/access/OwnableUpgradeable.sol";
import "@oz-up/utils/AddressUpgradeable.sol";
import "@oz-up/security/ReentrancyGuardUpgradeable.sol";

import "./lib/IReserve.sol";
import "./lib/ISortedOracles.sol";

import "./lib/FixidityLib.sol";
import "./lib/UsingRegistry.sol";
import "./lib/ICeloVersionedContract.sol";

/**
 * @title Ensures price stability of StableTokens with respect to their pegs
 */
contract MentoReserve is
    IReserve,
    ICeloVersionedContract,
    OwnableUpgradeable,
    UsingRegistry,
    ReentrancyGuardUpgradeable
{
    using FixidityLib for FixidityLib.Fraction;
    using AddressUpgradeable for address payable;

    struct TobinTaxCache {
        uint128 numerator;
        uint128 timestamp;
    }

    mapping(address => bool) public isToken;
    address[] private _tokens;
    TobinTaxCache public tobinTaxCache;
    uint256 public tobinTaxStalenessThreshold;
    uint256 public tobinTax;
    uint256 public tobinTaxReserveRatio;
    mapping(address => bool) public isSpender;

    mapping(address => bool) public isOtherReserveAddress;
    address[] public otherReserveAddresses;

    bytes32[] public assetAllocationSymbols;
    mapping(bytes32 => uint256) public assetAllocationWeights;

    uint256 public lastSpendingDay;
    uint256 public spendingLimit;
    FixidityLib.Fraction private spendingRatio;

    uint256 public frozenReserveGoldStartBalance;
    uint256 public frozenReserveGoldStartDay;
    uint256 public frozenReserveGoldDays;

    mapping(address => bool) public isExchangeSpender;
    address[] public exchangeSpenderAddresses;

    event TobinTaxStalenessThresholdSet(uint256 value);
    event DailySpendingRatioSet(uint256 ratio);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token, uint256 index);
    event SpenderAdded(address indexed spender);
    event SpenderRemoved(address indexed spender);
    event OtherReserveAddressAdded(address indexed otherReserveAddress);
    event OtherReserveAddressRemoved(address indexed otherReserveAddress, uint256 index);
    event AssetAllocationSet(bytes32[] symbols, uint256[] weights);
    event ReserveGoldTransferred(address indexed spender, address indexed to, uint256 value);
    event TobinTaxSet(uint256 value);
    event TobinTaxReserveRatioSet(uint256 value);
    event ExchangeSpenderAdded(address indexed exchangeSpender);
    event ExchangeSpenderRemoved(address indexed exchangeSpender);

    modifier isStableToken(address token) {
        require(isToken[token], "token addr was never registered");
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
        return (1, 1, 2, 2);
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
     * @param _tobinTaxStalenessThreshold The initial number of seconds to cache tobin tax value for.
     * @param _spendingRatio The relative daily spending limit for the reserve spender.
     * @param _frozenGold The balance of reserve gold that is frozen.
     * @param _frozenDays The number of days during which the frozen gold thaws.
     * @param _assetAllocationSymbols The symbols of the reserve assets.
     * @param _assetAllocationWeights The reserve asset weights.
     * @param _tobinTax The tobin tax value as a fixidity fraction.
     * @param _tobinTaxReserveRatio When to turn on the tobin tax, as a fixidity fraction.
     */
    function initialize(
        address registryAddress,
        uint256 _tobinTaxStalenessThreshold,
        uint256 _spendingRatio,
        uint256 _frozenGold,
        uint256 _frozenDays,
        bytes32[] calldata _assetAllocationSymbols,
        uint256[] calldata _assetAllocationWeights,
        uint256 _tobinTax,
        uint256 _tobinTaxReserveRatio
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        setRegistry(registryAddress);
        setTobinTaxStalenessThreshold(_tobinTaxStalenessThreshold);
        setDailySpendingRatio(_spendingRatio);
        setFrozenGold(_frozenGold, _frozenDays);
        setAssetAllocations(_assetAllocationSymbols, _assetAllocationWeights);
        setTobinTax(_tobinTax);
        setTobinTaxReserveRatio(_tobinTaxReserveRatio);
    }

    /**
     * @notice Sets the number of seconds to cache the tobin tax value for.
     * @param value The number of seconds to cache the tobin tax value for.
     */
    function setTobinTaxStalenessThreshold(uint256 value) public onlyOwner {
        require(value > 0, "value was zero");
        tobinTaxStalenessThreshold = value;
        emit TobinTaxStalenessThresholdSet(value);
    }

    /**
     * @notice Sets the tobin tax.
     * @param value The tobin tax.
     */
    function setTobinTax(uint256 value) public onlyOwner {
        require(FixidityLib.wrap(value).lte(FixidityLib.fixed1()), "tobin tax cannot be larger than 1");
        tobinTax = value;
        emit TobinTaxSet(value);
    }

    /**
     * @notice Sets the reserve ratio at which the tobin tax sets in.
     * @param value The reserve ratio at which the tobin tax sets in.
     */
    function setTobinTaxReserveRatio(uint256 value) public onlyOwner {
        tobinTaxReserveRatio = value;
        emit TobinTaxReserveRatioSet(value);
    }

    /**
     * @notice Set the ratio of reserve that is spendable per day.
     * @param ratio Spending ratio as unwrapped Fraction.
     */
    function setDailySpendingRatio(uint256 ratio) public onlyOwner {
        spendingRatio = FixidityLib.wrap(ratio);
        require(spendingRatio.lte(FixidityLib.fixed1()), "spending ratio cannot be larger than 1");
        emit DailySpendingRatioSet(ratio);
    }

    /**
     * @notice Get daily spending ratio.
     * @return Spending ratio as unwrapped Fraction.
     */
    function getDailySpendingRatio() public view returns (uint256) {
        return spendingRatio.unwrap();
    }

    /**
     * @notice Sets the balance of reserve gold frozen from transfer.
     * @param frozenGold The amount of CELO frozen.
     * @param frozenDays The number of days the frozen CELO thaws over.
     */
    function setFrozenGold(uint256 frozenGold, uint256 frozenDays) public onlyOwner {
        require(frozenGold <= address(this).balance, "Cannot freeze more than balance");
        frozenReserveGoldStartBalance = frozenGold;
        frozenReserveGoldStartDay = block.timestamp / 1 days;
        frozenReserveGoldDays = frozenDays;
    }

    /**
     * @notice Sets target allocations for CELO and a diversified basket of non-Celo assets.
     * @param symbols The symbol of each asset in the Reserve portfolio.
     * @param weights The weight for the corresponding asset as unwrapped Fixidity.Fraction.
     */
    function setAssetAllocations(bytes32[] memory symbols, uint256[] memory weights) public onlyOwner {
        require(symbols.length == weights.length, "Array length mismatch");
        FixidityLib.Fraction memory sum = FixidityLib.wrap(0);
        for (uint256 i = 0; i < weights.length; i++) {
            sum = sum.add(FixidityLib.wrap(weights[i]));
        }
        require(sum.equals(FixidityLib.fixed1()), "Sum of asset allocation must be 1");
        for (uint256 i = 0; i < assetAllocationSymbols.length; i++) {
            delete assetAllocationWeights[assetAllocationSymbols[i]];
        }
        assetAllocationSymbols = symbols;
        for (uint256 i = 0; i < symbols.length; i++) {
            require(assetAllocationWeights[symbols[i]] == 0, "Cannot set weight twice");
            assetAllocationWeights[symbols[i]] = weights[i];
        }
        // NOTE: The CELO asset launched as "Celo Gold" (cGLD), but was renamed to
        // just CELO by the community.
        // TODO: Change "cGLD" to "CELO" in this file, after ensuring that any
        // off chain tools working with asset allocation weights are aware of this
        // change.

        // NOTE: commented this out as this fork will not be using cGLD
        //require(assetAllocationWeights["cGLD"] != 0, "Must set cGLD asset weight");

        emit AssetAllocationSet(symbols, weights);
    }

    /**
     * @notice Add a token that the reserve will stabilize.
     * @param token The address of the token being stabilized.
     * @return Returns true if the transaction succeeds.
     */
    function addToken(address token) external onlyOwner nonReentrant returns (bool) {
        require(!isToken[token], "token addr already registered");
        isToken[token] = true;
        _tokens.push(token);
        emit TokenAdded(token);
        return true;
    }

    /**
     * @notice Remove a token that the reserve will no longer stabilize.
     * @param token The address of the token no longer being stabilized.
     * @param index The index of the token in _tokens.
     * @return Returns true if the transaction succeeds.
     */
    function removeToken(address token, uint256 index) external onlyOwner isStableToken(token) returns (bool) {
        require(index < _tokens.length && _tokens[index] == token, "index into tokens list not mapped to token");
        isToken[token] = false;
        address lastItem = _tokens[_tokens.length - 1];
        _tokens[index] = lastItem;
        _tokens.pop();
        emit TokenRemoved(token, index);
        return true;
    }

    /**
     * @notice Add a reserve address whose balance shall be included in the reserve ratio.
     * @param reserveAddress The reserve address to add.
     * @return Returns true if the transaction succeeds.
     */
    function addOtherReserveAddress(address reserveAddress) external onlyOwner nonReentrant returns (bool) {
        require(!isOtherReserveAddress[reserveAddress], "reserve addr already added");
        isOtherReserveAddress[reserveAddress] = true;
        otherReserveAddresses.push(reserveAddress);
        emit OtherReserveAddressAdded(reserveAddress);
        return true;
    }

    /**
     * @notice Remove reserve address whose balance shall no longer be included in the reserve ratio.
     * @param reserveAddress The reserve address to remove.
     * @param index The index of the reserve address in otherReserveAddresses.
     * @return Returns true if the transaction succeeds.
     */
    function removeOtherReserveAddress(address reserveAddress, uint256 index) external onlyOwner returns (bool) {
        require(isOtherReserveAddress[reserveAddress], "reserve addr was never added");
        require(
            index < otherReserveAddresses.length && otherReserveAddresses[index] == reserveAddress,
            "index into reserve list not mapped to address"
        );
        isOtherReserveAddress[reserveAddress] = false;
        address lastItem = otherReserveAddresses[otherReserveAddresses.length - 1];
        otherReserveAddresses[index] = lastItem;
        otherReserveAddresses.pop();
        emit OtherReserveAddressRemoved(reserveAddress, index);
        return true;
    }

    /**
     * @notice Gives an address permission to spend Reserve funds.
     * @param spender The address that is allowed to spend Reserve funds.
     */
    function addSpender(address spender) external onlyOwner {
        require(address(0) != spender, "Spender can't be null");
        isSpender[spender] = true;
        emit SpenderAdded(spender);
    }

    /**
     * @notice Takes away an address's permission to spend Reserve funds.
     * @param spender The address that is to be no longer allowed to spend Reserve funds.
     */
    function removeSpender(address spender) external onlyOwner {
        isSpender[spender] = false;
        emit SpenderRemoved(spender);
    }

    /**
     * @notice Checks if an address is able to spend as an exchange.
     * @dev isExchangeSpender was introduced after cUSD, so the cUSD Exchange is not included in it.
     * If cUSD's Exchange were to be added to isExchangeSpender, the check with the
     * registry could be removed.
     * @param spender The address to be checked.
     */
    modifier isAllowedToSpendExchange(address spender) {
        require(
            isExchangeSpender[spender] || (registry.getAddressForOrDie(EXCHANGE_REGISTRY_ID) == spender),
            "Address not allowed to spend"
        );
        _;
    }

    /**
     * @notice Gives an address permission to spend Reserve without limit.
     * @param spender The address that is allowed to spend Reserve funds.
     */
    function addExchangeSpender(address spender) external onlyOwner {
        require(address(0) != spender, "Spender can't be null");
        require(!isExchangeSpender[spender], "Address is already Exchange Spender");
        isExchangeSpender[spender] = true;
        exchangeSpenderAddresses.push(spender);
        emit ExchangeSpenderAdded(spender);
    }

    /**
     * @notice Takes away an address's permission to spend Reserve funds without limits.
     * @param spender The address that is to be no longer allowed to spend Reserve funds.
     * @param index The index in exchangeSpenderAddresses of spender.
     */
    function removeExchangeSpender(address spender, uint256 index) external onlyOwner {
        isExchangeSpender[spender] = false;
        uint256 numAddresses = exchangeSpenderAddresses.length;
        require(index < numAddresses, "Index is invalid");
        require(spender == exchangeSpenderAddresses[index], "Index does not match spender");
        uint256 newNumAddresses = numAddresses - 1;

        if (index != newNumAddresses) {
            exchangeSpenderAddresses[index] = exchangeSpenderAddresses[newNumAddresses];
        }
        exchangeSpenderAddresses.pop();
        emit ExchangeSpenderRemoved(spender);
    }

    /**
     * @notice Returns addresses of exchanges permitted to spend Reserve funds.
     * Because exchangeSpenderAddresses was introduced after cUSD, cUSD's exchange
     * is not included in this list.
     * @return An array of addresses permitted to spend Reserve funds.
     */
    function getExchangeSpenders() external view returns (address[] memory) {
        return exchangeSpenderAddresses;
    }

    /**
     * @notice Transfer gold to a whitelisted address subject to reserve spending limits.
     * @param to The address that will receive the gold.
     * @param value The amount of gold to transfer.
     * @return Returns true if the transaction succeeds.
     */
    function transferGold(address payable to, uint256 value) external returns (bool) {
        require(isSpender[msg.sender], "sender not allowed to transfer Reserve funds");
        require(isOtherReserveAddress[to], "can only transfer to other reserve address");
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastSpendingDay) {
            uint256 balance = getUnfrozenReserveGoldBalance();
            lastSpendingDay = currentDay;
            spendingLimit = spendingRatio.multiply(FixidityLib.newFixed(balance)).fromFixed();
        }
        require(spendingLimit >= value, "Exceeding spending limit");
        spendingLimit -= value;
        return _transferGold(to, value);
    }

    /**
     * @notice Transfer unfrozen gold to any address.
     * @param to The address that will receive the gold.
     * @param value The amount of gold to transfer.
     * @return Returns true if the transaction succeeds.
     */
    function _transferGold(address payable to, uint256 value) internal returns (bool) {
        require(value <= getUnfrozenBalance(), "Exceeding unfrozen reserves");
        to.sendValue(value);
        emit ReserveGoldTransferred(msg.sender, to, value);
        return true;
    }

    /**
     * @notice Transfer unfrozen gold to any address, used for one side of CP-DOTO.
     * @dev Transfers are not subject to a daily spending limit.
     * @param to The address that will receive the gold.
     * @param value The amount of gold to transfer.
     * @return Returns true if the transaction succeeds.
     */
    function transferExchangeGold(address payable to, uint256 value)
        external
        isAllowedToSpendExchange(msg.sender)
        returns (bool)
    {
        return _transferGold(to, value);
    }

    /**
     * @notice Returns the tobin tax, recomputing it if it's stale.
     * @return The numerator - tobin tax amount as a fraction.
     * @return The denominator - tobin tax amount as a fraction.
     */
    function getOrComputeTobinTax() external nonReentrant returns (uint256, uint256) {
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp - tobinTaxCache.timestamp > tobinTaxStalenessThreshold) {
            tobinTaxCache.numerator = uint128(computeTobinTax().unwrap());
            tobinTaxCache.timestamp = uint128(block.timestamp); // solhint-disable-line not-rely-on-time
        }
        return (uint256(tobinTaxCache.numerator), FixidityLib.fixed1().unwrap());
    }

    /**
     * @notice Returns the list of stabilized token addresses.
     * @return An array of addresses of stabilized tokens.
     */
    function getTokens() external view returns (address[] memory) {
        return _tokens;
    }

    /**
     * @notice Returns the list other addresses included in the reserve total.
     * @return An array of other addresses included in the reserve total.
     */
    function getOtherReserveAddresses() external view returns (address[] memory) {
        return otherReserveAddresses;
    }

    /**
     * @notice Returns a list of token symbols that have been allocated.
     * @return An array of token symbols that have been allocated.
     */
    function getAssetAllocationSymbols() external view returns (bytes32[] memory) {
        return assetAllocationSymbols;
    }

    /**
     * @notice Returns a list of weights used for the allocation of reserve assets.
     * @return An array of a list of weights used for the allocation of reserve assets.
     */
    function getAssetAllocationWeights() external view returns (uint256[] memory) {
        uint256[] memory weights = new uint256[](assetAllocationSymbols.length);
        for (uint256 i = 0; i < assetAllocationSymbols.length; i++) {
            weights[i] = assetAllocationWeights[assetAllocationSymbols[i]];
        }
        return weights;
    }

    /**
     * @notice Returns the amount of unfrozen CELO in the reserve.
     * @return The total unfrozen CELO in the reserve.
     */
    function getUnfrozenBalance() public view returns (uint256) {
        uint256 balance = address(this).balance;
        uint256 frozenReserveGold = getFrozenReserveGoldBalance();
        return balance > frozenReserveGold ? balance - frozenReserveGold : 0;
    }

    /**
     * @notice Returns the amount of CELO included in the reserve.
     * @return The CELO amount included in the reserve.
     */
    function getReserveGoldBalance() public view returns (uint256) {
        return address(this).balance + getOtherReserveAddressesGoldBalance();
    }

    /**
     * @notice Returns the amount of CELO included in other reserve addresses.
     * @return The CELO amount included in other reserve addresses.
     */
    function getOtherReserveAddressesGoldBalance() public view returns (uint256) {
        uint256 reserveGoldBalance = 0;
        for (uint256 i = 0; i < otherReserveAddresses.length; i++) {
            reserveGoldBalance = reserveGoldBalance + otherReserveAddresses[i].balance;
        }
        return reserveGoldBalance;
    }

    /**
     * @notice Returns the amount of unfrozen CELO included in the reserve.
     * @return The unfrozen CELO amount included in the reserve.
     */
    function getUnfrozenReserveGoldBalance() public view returns (uint256) {
        return getUnfrozenBalance() + getOtherReserveAddressesGoldBalance();
    }

    /**
     * @notice Returns the amount of frozen CELO in the reserve.
     * @return The total frozen CELO in the reserve.
     */
    function getFrozenReserveGoldBalance() public view returns (uint256) {
        uint256 currentDay = block.timestamp / 1 days;
        uint256 frozenDays = currentDay - frozenReserveGoldStartDay;
        if (frozenDays >= frozenReserveGoldDays) return 0;
        return frozenReserveGoldStartBalance - (frozenReserveGoldStartBalance * frozenDays / frozenReserveGoldDays);
    }

    /**
     * @notice Computes the ratio of current reserve balance to total stable token valuation.
     * @return Reserve ratio in a fixed point format.
     */
    function getReserveRatio() public view returns (uint256) {
        address sortedOraclesAddress = registry.getAddressForOrDie(SORTED_ORACLES_REGISTRY_ID);
        ISortedOracles sortedOracles = ISortedOracles(sortedOraclesAddress);
        uint256 reserveGoldBalance = getUnfrozenReserveGoldBalance();
        uint256 stableTokensValueInGold = 0;
        FixidityLib.Fraction memory cgldWeight = FixidityLib.wrap(assetAllocationWeights["cGLD"]);

        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 stableAmount;
            uint256 goldAmount;
            (stableAmount, goldAmount) = sortedOracles.medianRate(_tokens[i]);

            if (goldAmount != 0) {
                // tokens with no oracle reports don't count towards collateralization ratio
                uint256 stableTokenSupply = IERC20(_tokens[i]).totalSupply();
                uint256 aStableTokenValueInGold = stableTokenSupply * goldAmount / stableAmount;
                stableTokensValueInGold += aStableTokenValueInGold;
            }
        }
        return FixidityLib.newFixed(reserveGoldBalance).divide(cgldWeight).divide(
            FixidityLib.newFixed(stableTokensValueInGold)
        ).unwrap();
    }

    /*
    * Internal functions
    */

    /**
     * @notice Computes a tobin tax based on the reserve ratio.
     * @return The tobin tax expresesed as a fixidity fraction.
     */
    function computeTobinTax() private view returns (FixidityLib.Fraction memory) {
        FixidityLib.Fraction memory ratio = FixidityLib.wrap(getReserveRatio());
        if (ratio.gte(FixidityLib.wrap(tobinTaxReserveRatio))) {
            return FixidityLib.wrap(0);
        } else {
            return FixidityLib.wrap(tobinTax);
        }
    }
}
