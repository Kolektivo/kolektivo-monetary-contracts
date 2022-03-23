// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {Ownable} from "solrocket/Ownable.sol";

import "./lib/Select.sol";

interface IOracle {
    function getData() external returns (uint, bool);
}

/**
 * @title KTT's Oracle
 *
 * @dev Provides value onchain that's aggregated from a whitelisted set of
 *      providers.
 *
 * @author Ampleforth
 * @author byterocket
 */
contract Oracle is Ownable, IOracle {

    struct Report {
        uint timestamp;
        uint payload;
    }

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Invalid provider.
    /// @param invalidProvider The address of the invalid provider.
    error InvalidProvider(address invalidProvider);

    /// @notice Report pushed to soon after past report.
    error NewReportTooSoonAfterPastReport();

    //--------------------------------------------------------------------------
    // Events

    /// @notice Emitted when a new report is pushed.
    /// @param provider The address of the provider who pushed the report.
    /// @param payload The payload of the report.
    /// @param timestamp The timestamp of the report.
    event ProviderReportPushed(address indexed provider,
                               uint payload,
                               uint timestamp);

    /// @notice Emitted when a report's timestamp is out of range.
    /// @param provider The addresss of the provider whos report was invalid.
    event ReportTimestampOutOfRange(address indexed provider);

    /// @notice Emitted when a new provider is added.
    /// @param provider The address of the newly added provider.
    event ProviderAdded(address indexed provider);

    /// @notice Emitted when a provider is removed.
    /// @param provider The address of the removed provider.
    event ProviderRemoved(address indexed provider);

    /// @notice Emitted when the minimum providers needed is changed.
    /// @param oldMinimumProviders The old number of minimum providers.
    /// @param newMinimumProviders The new number of minimum providers.
    event MinimumProvidersChanged(uint oldMinimumProviders,
                                  uint newMinimumProviders);

    /// @notice Emitted when reports from a provider are purged.
    /// @param purger The address who purged the reports.
    /// @param provider The address of the provider whos reports were purged.
    event ProviderReportsPurged(address indexed purger,
                                address indexed provider);

    /// @notice Emitted when the oracle is marked as invalid.
    event OracleMarkedAsInvalid();

    /// @notice Emitted when the oracle is marked as valid.
    event OracleMarkedAsValid();

    //--------------------------------------------------------------------------
    // Storage

    /// @notice The number of seconds after which a report is deemed expired.
    uint public immutable reportExpirationTime;

    /// @notice The number of seconds since reporting that has to pass before
    ///         a report is usable.
    /// @dev Gives a buffer to purge reports in case of faulty payload.
    uint public immutable reportDelay;

    /// @notice Addresses of providers authorized to push reports.
    /// @dev Changeable by owner.
    address[] public providers;

    /// @notice Mapping of reports indexed by provider addresses.
    /// @dev Report[0].timestamp > 0 indicates provider's existence.
    mapping(address => Report[2]) public providerReports;

    /// @notice The minimum number of providers with valid reports to consider
    ///         the aggregate report valid.
    /// @dev Changeable by owner.
    uint public minimumProviders;

    /// @notice Flag to indicate if oracle delivers correct value.
    /// @dev Changeable by owner.
    bool public isValid;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(
        uint reportExpirationTime_,
        uint reportDelay_,
        uint minimumProviders_
    ) {
        // Make sure that two reports from same provider can be valid.
        require(reportExpirationTime_ > 2 * reportDelay_);
        // Make sure that at least one provider has to deliver reports.
        require(minimumProviders_ != 0);

        // Set storage.
        reportExpirationTime = reportExpirationTime_;
        reportDelay = reportDelay_;
        minimumProviders = minimumProviders_;

        // Mark oracle as valid.
        isValid = true;
        emit OracleMarkedAsValid();
    }

    //--------------------------------------------------------------------------
    // Provider Functions

    /// @notice Pushes a new report to the oracle.
    /// @dev Only callable by providers.
    /// @dev Only callable if at least reportDelay seconds passed since last
    ///      report.
    /// @param payload The report's data.
    function pushReport(uint payload) external {
        Report[2] storage reports = providerReports[msg.sender];
        uint[2] memory timestamps = [reports[0].timestamp, reports[1].timestamp];

        // Check if provider exists.
        if (timestamps[0] == 0) {
            revert InvalidProvider(msg.sender);
        }

        // Should report be pushed to index 0 or index 1?
        uint8 indexRecent = timestamps[0] >= timestamps[1] ? 0 : 1;
        uint8 indexPast = 1 - indexRecent;

        // Check that report is not too soon after the last one.
        if (timestamps[indexRecent] + reportDelay > block.timestamp) {
            revert NewReportTooSoonAfterPastReport();
        }

        // Save new report.
        reports[indexPast].timestamp = block.timestamp;
        reports[indexPast].payload = payload;

        emit ProviderReportPushed(msg.sender, payload, block.timestamp);
    }

    /// @notice Purges all reports from msg.sender.
    /// @dev Only callable by providers.
    function purgeReports() external {
        // Check if provider exists.
        if (providerReports[msg.sender][0].timestamp == 0) {
            revert InvalidProvider(msg.sender);
        }

        emit ProviderReportsPurged(msg.sender, msg.sender);

        // Set report timestamp to 1 to mark it as invalid.
        providerReports[msg.sender][0].timestamp = 1;
        providerReports[msg.sender][1].timestamp = 1;
    }

    //--------------------------------------------------------------------------
    // IOracle Functions

    /// @notice Returns the oracle data and a boolean indicating if data is
    ///         valid.
    function getData() external override(IOracle) returns (uint, bool) {
        // Return early if oracle is marked as invalid.
        if (!isValid) {
            return (0, false);
        }

        uint reportsCount = providers.length;
        uint[] memory validReports = new uint[](reportsCount);
        uint size;

        // Get for each provider the average of their report payloads.
        for (uint i; i < reportsCount; ) {
            uint result;
            bool valid;
            (result, valid) = _getAverageReportPayload(providers[i]);

            if (valid) {
                validReports[size++] = result;
            }

            unchecked { ++i; }
        }

        // Check that enough reports are used.
        if (size < minimumProviders) {
            return (0, false);
        }

        // Return the median of the results.
        return (Select.computeMedian(validReports, size), true);
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    function providersSize() external view returns (uint) {
        return providers.length;
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    /// @notice Changes the oracle's validity.
    /// @dev Only callable by owner.
    /// @param isValid_ Wether the oracle should be marked as valid or invalid.
    function setIsValid(bool isValid_) external onlyOwner {
        // Only emit event if state changed.
        if (isValid_ && !isValid) {
            isValid = true;
            emit OracleMarkedAsValid();
            return;
        }

        if (!isValid_ && isValid) {
            isValid = false;
            emit OracleMarkedAsInvalid();
            return;
        }
    }

    /// @notice Sets the minimum number of different providers necessary to
    ///         deliver reports for the oracle data to be valid.
    /// @dev Only callable by owner.
    /// @param minimumProviders_ The minimum number of providers.
    function setMinimumProviders(uint minimumProviders_) external onlyOwner {
        // Make sure that at least one provider has to deliver reports.
        require(minimumProviders_ != 0);

        emit MinimumProvidersChanged(minimumProviders, minimumProviders_);

        minimumProviders = minimumProviders_;
    }

    /// @notice Purges all reports from given provider.
    /// @dev Only callable by owner.
    /// @param provider The provider which reports should be purged.
    function purgeReportsFrom(address provider) external onlyOwner {
        // Check if provider exists.
        if (providerReports[provider][0].timestamp == 0) {
            revert InvalidProvider(provider);
        }

        emit ProviderReportsPurged(msg.sender, provider);

        // Set report timestamp to 1 to mark it as invalid.
        providerReports[provider][0].timestamp = 1;
        providerReports[provider][1].timestamp = 1;
    }

    /// @notice Adds a new provider eligible to push reports.
    /// @dev Only callable by owner.
    /// @param provider The provider to add.
    function addProvider(address provider) external onlyOwner {
        // Do nothing if provider is already eligible to push reports.
        if (providerReports[provider][0].timestamp != 0) {
            return;
        }

        providers.push(provider);
        // Note to initialize provider's first report with timestamp of 1.
        providerReports[provider][0].timestamp = 1;

        emit ProviderAdded(provider);
    }

    /// @notice Removes a provider from being eligible to push reports.
    /// @dev Purges all reports from the provider.
    /// @dev Only callable by owner.
    /// @param provider The provider to remove.
    function removeProvider(address provider) external onlyOwner {
        // Remove provider's reports.
        delete providerReports[provider];

        // Remove provider.
        uint len = providers.length;
        for (uint i; i < len; ) {
            if (providers[i] == provider) {
                // If not last elem in array, copy last elem to this index.
                if (i + 1 != len) {
                    providers[i] = providers[len - 1];
                }
                providers.pop();
                emit ProviderRemoved(provider);
                break;
            }

            unchecked { ++i; }
        }
    }

    //--------------------------------------------------------------------------
    // Private Functions

    /// @dev Returns the average of all valid report's payloads pushed by given
    ///      provider.
    function _getAverageReportPayload(address provider)
        private
        returns (uint, bool)
    {
        uint minValidTimestamp = block.timestamp - reportExpirationTime;
        uint maxValidTimestamp = block.timestamp - reportDelay;

        Report[2] memory reports = providerReports[provider];

        // Get index of recent and past reports.
        uint8 indexRecent = reports[0].timestamp >= reports[1].timestamp
                            ? 0
                            : 1;
        uint8 indexPast = 1 - indexRecent;

        // Cache timestamp and payload from reports.
        uint recentReportTimestamp = reports[indexRecent].timestamp;
        uint pastReportTimestamp = reports[indexPast].timestamp;
        uint recentReportPayload = providerReports[provider][indexRecent].payload;
        uint pastReportPayload = providerReports[provider][indexPast].payload;

        // Compute the validity of the reports.
        bool recentReportUsable = recentReportTimestamp <= maxValidTimestamp
                               && recentReportTimestamp >= minValidTimestamp;
        bool pastReportUsable = pastReportTimestamp <= maxValidTimestamp
                             && pastReportTimestamp >= minValidTimestamp;

        if (recentReportUsable) {
            if (pastReportUsable) {
                // Both reports usable, therefore use the average.
                // Note that >> 1 is equal to a division by 2.
                return ((recentReportPayload + pastReportPayload) >> 1, true);
            } else {
                // Only recent report usable.
                emit ReportTimestampOutOfRange(provider);
                return (recentReportPayload, true);
            }
        } else {
            if (pastReportUsable) {
                // Only past report usable.
                emit ReportTimestampOutOfRange(provider);
                return (pastReportPayload, true);
            } else {
                // No report usable.
                emit ReportTimestampOutOfRange(provider);
                return (0, false);
            }
        }
    }

}