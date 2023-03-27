pragma solidity 0.8.10;

interface IStableToken {
  function mint(address, uint256) external returns (bool);
  function burn(uint256) external returns (bool);
  function setInflationParameters(uint256, uint256) external;
  function valueToUnits(uint256) external view returns (uint256);
  function unitsToValue(uint256) external view returns (uint256);
  function getInflationParameters() external view returns (uint256, uint256, uint256, uint256);

  // NOTE: duplicated with IERC20.sol, remove once interface inheritance is supported.
  function balanceOf(address) external view returns (uint256);
}