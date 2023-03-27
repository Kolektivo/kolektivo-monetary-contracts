pragma solidity 0.8.10;

interface IGovernance {
  function isVoting(address) external view returns (bool);
}