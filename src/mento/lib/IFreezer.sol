pragma solidity 0.8.17;

interface IFreezer {
  function isFrozen(address) external view returns (bool);
}