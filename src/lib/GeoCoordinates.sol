// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

/**
 * @title GeoCoordinates Library
 *
 * @dev Provides functionality to validate latitude and longitude coordinates.
 *
 * @author byterocket
 */
library GeoCoordinates {
    int32 private constant MAX_LATITUDE = 180_000_000;
    int32 private constant MIN_LATITUDE = -180_000_000;

    int32 private constant MAX_LONGITUDE = 90_000_000;
    int32 private constant MIN_LONGITUDE = -90_000_000;

    /// @notice Returns whether the given latitude coordinate is valid.
    /// @param latitude The latitude coordinate.
    /// @return True if latitude coordinate valid, false otherwise.
    function isValidLatitudeCoordinate(int32 latitude)
        internal
        pure
        returns (bool)
    {
        return latitude >= MIN_LATITUDE && latitude <= MAX_LATITUDE;
    }

    /// @notice Returns whether the given longitude coordinate is valid.
    /// @param longitude The longitude coordinate.
    /// @return True if longitude coordinate valid, false otherwise.
    function isValidLongitudeCoordinate(int32 longitude)
        internal
        pure
        returns (bool)
    {
        return longitude >= MIN_LONGITUDE && longitude <= MAX_LONGITUDE;
    }
}
