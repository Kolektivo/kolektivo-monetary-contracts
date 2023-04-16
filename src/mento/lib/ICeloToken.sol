pragma solidity 0.8.10;

interface ICeloToken {
    function transferWithComment(address, uint256, string calldata) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
