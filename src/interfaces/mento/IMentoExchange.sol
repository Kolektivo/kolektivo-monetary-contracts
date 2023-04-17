// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IMentoExchange {
    function buy(uint256, uint256, bool) external returns (uint256);
    function sell(uint256, uint256, bool) external returns (uint256);
    function exchange(uint256, uint256, bool) external returns (uint256);
    function setUpdateFrequency(uint256) external;
    function getBuyTokenAmount(uint256, bool) external view returns (uint256);
    function getSellTokenAmount(uint256, bool) external view returns (uint256);
    function getBuyAndSellBuckets(bool) external view returns (uint256, uint256);
}
