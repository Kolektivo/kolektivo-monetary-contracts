pragma solidity 0.8.10;

interface IFreezer {
  function isFrozen(address) external view returns (bool);
}