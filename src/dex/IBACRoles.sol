pragma solidity 0.8.10;

contract Enum {
    enum Operation {Call, DelegateCall}
}
interface IBACRoles {
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 badgeId
    ) external returns (bool success);
}