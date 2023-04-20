// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "@oz/access/Ownable.sol";
import "@oz/proxy/utils/Initializable.sol";

import "./lib/ISortedOracles.sol";
import "./lib/ICeloVersionedContract.sol";
import "./lib/IBreakerBox.sol";

import "./lib/FixidityLib.sol";
import "./lib/AddressSortedLinkedListWithMedian.sol";
import "./lib/SortedLinkedListWithMedian.sol";

/**
 * @title   SortedOracles
 *
 * @notice  This contract stores a collection of exchange rate reports between mento
 *          collateral assets and other currencies. The most recent exchange rates
 *          are gathered off-chain by oracles, who then use the `report` function to
 *          submit the rates to this contract. Before submitting a rate report, an
 *          oracle's address must be added to the `isOracle` mapping for a specific
 *          rateFeedId, with the flag set to true. While submitting a report requires
 *          an address to be added to the mapping, no additional permissions are needed
 *          to read the reports, the calculated median rate, or the list of oracles.
 *
 * @dev     A unique rateFeedId identifies each exchange rate. In the initial implementation
 *          of this contract, the rateFeedId was set as the address of the mento stable
 *          asset contract that used the rate. However, this implementation has since
 *          been updated, and the rateFeedId now refers to an address derived from the
 *          concatenation of the mento collateral asset and the currency symbols' hash.
 *          This change enables the contract to store multiple exchange rates for a
 *          single stable asset. As a result of this change, there may be instances
 *          where the term "token" is used in the contract code. These useages of the term
 *          "token" are actually referring to the rateFeedId. You can refer to the Mento
 *          protocol documentation to learn more about the rateFeedId and how it is derived.
 *
 */
contract SortedOracles is ISortedOracles, ICeloVersionedContract, Ownable, Initializable {
    using AddressSortedLinkedListWithMedian for SortedLinkedListWithMedian.List;
    using FixidityLib for FixidityLib.Fraction;

    uint256 private constant FIXED1_UINT = 1e24;

    // Maps a rateFeedID to a sorted list of report values.
    mapping(address => SortedLinkedListWithMedian.List) private rates;
    // Maps a rateFeedID to a sorted list of report timestamps.
    mapping(address => SortedLinkedListWithMedian.List) private timestamps;
    mapping(address => mapping(address => bool)) public isOracle;
    mapping(address => address[]) public oracles;

    // `reportExpirySeconds` is the fallback value used to determine reporting
    // frequency. Initially it was the _only_ value but we later introduced
    // the per token mapping in `tokenReportExpirySeconds`. If a token
    // doesn't have a value in the mapping (i.e. it's 0), the fallback is used.
    // See: #getTokenReportExpirySeconds
    uint256 public reportExpirySeconds;
    // Maps a rateFeedId to its report expiry time in seconds.
    mapping(address => uint256) public tokenReportExpirySeconds;

    IBreakerBox public breakerBox;

    event OracleAdded(address indexed token, address indexed oracleAddress);
    event OracleRemoved(address indexed token, address indexed oracleAddress);
    event OracleReported(address indexed token, address indexed oracle, uint256 timestamp, uint256 value);
    event OracleReportRemoved(address indexed token, address indexed oracle);
    event MedianUpdated(address indexed token, uint256 value);
    event ReportExpirySet(uint256 reportExpiry);
    event TokenReportExpirySet(address token, uint256 reportExpiry);
    event BreakerBoxUpdated(address indexed newBreakerBox);

    modifier onlyOracle(address token) {
        require(isOracle[token][msg.sender], "sender was not an oracle for token addr");
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
        return (1, 1, 2, 1);
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
     * @param _reportExpirySeconds The number of seconds before a report is considered expired.
     */
    function initialize(uint256 _reportExpirySeconds) external initializer {
        _transferOwnership(msg.sender);
        setReportExpiry(_reportExpirySeconds);
    }

    /**
     * @notice Sets the report expiry parameter.
     * @param _reportExpirySeconds The number of seconds before a report is considered expired.
     */
    function setReportExpiry(uint256 _reportExpirySeconds) public onlyOwner {
        require(_reportExpirySeconds > 0, "report expiry seconds must be > 0");
        require(_reportExpirySeconds != reportExpirySeconds, "reportExpirySeconds hasn't changed");
        reportExpirySeconds = _reportExpirySeconds;
        emit ReportExpirySet(_reportExpirySeconds);
    }

    /**
     * @notice Sets the report expiry parameter for a rateFeedId.
     * @param _token The rateFeedId for which the expiry is to be set.
     * @param _reportExpirySeconds The number of seconds before a report is considered expired.
     */
    function setTokenReportExpiry(address _token, uint256 _reportExpirySeconds) external onlyOwner {
        require(_reportExpirySeconds > 0, "report expiry seconds must be > 0");
        require(_reportExpirySeconds != tokenReportExpirySeconds[_token], "token reportExpirySeconds hasn't changed");
        tokenReportExpirySeconds[_token] = _reportExpirySeconds;
        emit TokenReportExpirySet(_token, _reportExpirySeconds);
    }

    /**
     * @notice Sets the address of the BreakerBox.
     * @param newBreakerBox The new BreakerBox address.
     */
    function setBreakerBox(IBreakerBox newBreakerBox) public onlyOwner {
        require(address(newBreakerBox) != address(0), "BreakerBox address must be set");
        breakerBox = newBreakerBox;
        emit BreakerBoxUpdated(address(newBreakerBox));
    }

    /**
     * @notice Adds a new Oracle for a specified rate feed.
     * @param token The rateFeedId that the specified oracle is permitted to report.
     * @param oracleAddress The address of the oracle.
     */
    function addOracle(address token, address oracleAddress) external onlyOwner {
        // solhint-disable-next-line reason-string
        require(
            token != address(0) && oracleAddress != address(0) && !isOracle[token][oracleAddress],
            "token addr was null or oracle addr was null or oracle addr is already an oracle for token addr"
        );
        isOracle[token][oracleAddress] = true;
        oracles[token].push(oracleAddress);
        emit OracleAdded(token, oracleAddress);
    }

    /**
     * @notice Removes an Oracle from a specified rate feed.
     * @param token The rateFeedId that the specified oracle is no longer permitted to report.
     * @param oracleAddress The address of the oracle.
     * @param index The index of `oracleAddress` in the list of oracles.
     */
    function removeOracle(address token, address oracleAddress, uint256 index) external onlyOwner {
        // solhint-disable-next-line reason-string
        require(
            token != address(0) && oracleAddress != address(0) && oracles[token].length > index
                && oracles[token][index] == oracleAddress,
            "token addr null or oracle addr null or index of token oracle not mapped to oracle addr"
        );
        isOracle[token][oracleAddress] = false;
        if (index != oracles[token].length - 1) {
            oracles[token][index] = oracles[token][oracles[token].length - 1];
        }
        oracles[token].pop();
        if (reportExists(token, oracleAddress)) {
            removeReport(token, oracleAddress);
        }
        emit OracleRemoved(token, oracleAddress);
    }

    /**
     * @notice Removes a report that is expired.
     * @param token The rateFeedId of the report to be removed.
     * @param n The number of expired reports to remove, at most (deterministic upper gas bound).
     */
    function removeExpiredReports(address token, uint256 n) external {
        require(
            token != address(0) && n < timestamps[token].getNumElements(),
            "token addr null or trying to remove too many reports"
        );
        for (uint256 i = 0; i < n; i++) {
            (bool isExpired, address oldestAddress) = isOldestReportExpired(token);
            if (isExpired) {
                removeReport(token, oldestAddress);
            } else {
                break;
            }
        }
    }

    /**
     * @notice Check if last report is expired.
     * @param token The rateFeedId of the reports to be checked.
     * @return bool A bool indicating if the last report is expired.
     * @return address Oracle address of the last report.
     */
    function isOldestReportExpired(address token) public view returns (bool, address) {
        // solhint-disable-next-line reason-string
        require(token != address(0));
        address oldest = timestamps[token].getTail();
        uint256 timestamp = timestamps[token].getValue(oldest);
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp - timestamp >= getTokenReportExpirySeconds(token)) {
            return (true, oldest);
        }
        return (false, oldest);
    }

    /**
     * @notice Updates an oracle value and the median.
     * @param token The rateFeedId for the rate that is being reported.
     * @param value The number of stable asset that equate to one unit of collateral asset, for the
     *              specified rateFeedId, expressed as a fixidity value.
     * @param lesserKey The element which should be just left of the new oracle value.
     * @param greaterKey The element which should be just right of the new oracle value.
     * @dev Note that only one of `lesserKey` or `greaterKey` needs to be correct to reduce friction.
     */
    function report(address token, uint256 value, address lesserKey, address greaterKey) external onlyOracle(token) {
        uint256 originalMedian = rates[token].getMedianValue();
        if (rates[token].contains(msg.sender)) {
            rates[token].update(msg.sender, value, lesserKey, greaterKey);

            // Rather than update the timestamp, we remove it and re-add it at the
            // head of the list later. The reason for this is that we need to handle
            // a few different cases:
            //   1. This oracle is the only one to report so far. lesserKey = address(0)
            //   2. Other oracles have reported since this one's last report. lesserKey = getHead()
            //   3. Other oracles have reported, but the most recent is this one.
            //      lesserKey = key immediately after getHead()
            //
            // However, if we just remove this timestamp, timestamps[token].getHead()
            // does the right thing in all cases.
            timestamps[token].remove(msg.sender);
        } else {
            rates[token].insert(msg.sender, value, lesserKey, greaterKey);
        }
        timestamps[token].insert(
            msg.sender,
            // solhint-disable-next-line not-rely-on-time
            block.timestamp,
            timestamps[token].getHead(),
            address(0)
        );
        emit OracleReported(token, msg.sender, block.timestamp, value);
        uint256 newMedian = rates[token].getMedianValue();
        if (newMedian != originalMedian) {
            emit MedianUpdated(token, newMedian);
        }

        if (address(breakerBox) != address(0)) {
            breakerBox.checkAndSetBreakers(token);
        }
    }

    /**
     * @notice Returns the number of rates that are currently stored for a specifed rateFeedId.
     * @param token The rateFeedId for which to retrieve the number of rates.
     * @return uint256 The number of reported oracle rates stored for the given rateFeedId.
     */
    function numRates(address token) public view returns (uint256) {
        return rates[token].getNumElements();
    }

    /**
     * @notice Returns the median of the currently stored rates for a specified rateFeedId.
     * @param token The rateFeedId of the rates for which the median value is being retrieved.
     * @return uint256 The median exchange rate for rateFeedId.
     * @return fixidity
     */
    function medianRate(address token) external view returns (uint256, uint256) {
        return (rates[token].getMedianValue(), numRates(token) == 0 ? 0 : FIXED1_UINT);
    }

    /**
     * @notice Gets all elements from the doubly linked list.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return keys Keys of nn unpacked list of elements from largest to smallest.
     * @return values Values of an unpacked list of elements from largest to smallest.
     * @return relations Relations of an unpacked list of elements from largest to smallest.
     */
    function getRates(address token)
        external
        view
        returns (address[] memory, uint256[] memory, SortedLinkedListWithMedian.MedianRelation[] memory)
    {
        return rates[token].getElements();
    }

    /**
     * @notice Returns the number of timestamps.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return uint256 The number of oracle report timestamps for the specified rateFeedId.
     */
    function numTimestamps(address token) public view returns (uint256) {
        return timestamps[token].getNumElements();
    }

    /**
     * @notice Returns the median timestamp.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return uint256 The median report timestamp for the specified rateFeedId.
     */
    function medianTimestamp(address token) external view returns (uint256) {
        return timestamps[token].getMedianValue();
    }

    /**
     * @notice Gets all elements from the doubly linked list.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @return keys Keys of nn unpacked list of elements from largest to smallest.
     * @return values Values of an unpacked list of elements from largest to smallest.
     * @return relations Relations of an unpacked list of elements from largest to smallest.
     */
    function getTimestamps(address token)
        external
        view
        returns (address[] memory, uint256[] memory, SortedLinkedListWithMedian.MedianRelation[] memory)
    {
        return timestamps[token].getElements();
    }

    /**
     * @notice Checks if a report exists for a specified rateFeedId from a given oracle.
     * @param token The rateFeedId to be checked.
     * @param oracle The oracle whose report should be checked.
     * @return bool True if a report exists, false otherwise.
     */
    function reportExists(address token, address oracle) internal view returns (bool) {
        return rates[token].contains(oracle) && timestamps[token].contains(oracle);
    }

    /**
     * @notice Returns the list of oracles for a speficied rateFeedId.
     * @param token The rateFeedId whose oracles should be returned.
     * @return address[] A list of oracles for the given rateFeedId.
     */
    function getOracles(address token) external view returns (address[] memory) {
        return oracles[token];
    }

    /**
     * @notice Returns the expiry for specified rateFeedId if it exists, if not the default is returned.
     * @param token The rateFeedId.
     * @return The report expiry in seconds.
     */
    function getTokenReportExpirySeconds(address token) public view returns (uint256) {
        if (tokenReportExpirySeconds[token] == 0) {
            return reportExpirySeconds;
        }

        return tokenReportExpirySeconds[token];
    }

    /**
     * @notice Removes an oracle value and updates the median.
     * @param token The rateFeedId for which the collateral asset exchange rate is being reported.
     * @param oracle The oracle whose value should be removed.
     * @dev This can be used to delete elements for oracles that have been removed.
     * However, a > 1 elements reports list should always be maintained
     */
    function removeReport(address token, address oracle) private {
        if (numTimestamps(token) == 1 && reportExists(token, oracle)) return;
        uint256 originalMedian = rates[token].getMedianValue();
        rates[token].remove(oracle);
        timestamps[token].remove(oracle);
        emit OracleReportRemoved(token, oracle);
        uint256 newMedian = rates[token].getMedianValue();
        if (newMedian != originalMedian) {
            emit MedianUpdated(token, newMedian);
        }
    }
}
