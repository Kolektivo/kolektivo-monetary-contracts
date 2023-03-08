pragma solidity 0.8.17;

interface IGovernance {
  function isVoting(address) external view returns (bool);
}