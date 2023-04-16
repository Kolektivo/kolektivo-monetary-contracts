pragma solidity 0.8.10;

interface IFeeCurrencyWhitelist {
    function addToken(address) external;
    function getWhitelist() external view returns (address[] memory);
}
