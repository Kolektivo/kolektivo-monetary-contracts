// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/Treasury.sol";

/**
 * Errors library for Treasury's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner
        = abi.encodeWithSignature("OnlyCallableByOwner()");

    // Inherited from pmerkleplant/elastic-receipt-token.sol.
    bytes internal constant InvalidAmount
        = abi.encodeWithSignature("InvalidAmount()");
    bytes internal constant InvalidRecipient
        = abi.encodeWithSignature("InvalidRecipient()");

    function ERC20IsNotBondable(address erc20)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__ERC20IsNotBondable(address)",
            erc20
        );
    }

    function ERC20IsNotRedeemable(address erc20)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__ERC20IsNotRedeemable(address)",
            erc20
        );
    }

    function ERC20IsNotRegistered(address erc20)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__ERC20IsNotRegistered(address)",
            erc20
        );
    }

    function StalePriceDeliveredByOracle(address erc20, address oracle)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "Treasury__StaleERC20PriceDeliveredByOracle(address,address)",
            erc20,
            oracle
        );
    }
}

/**
 * @dev Root Contract for Treasury Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
abstract contract TreasuryTest is Test {
    // SuT.
    Treasury treasury;

    // Events copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event ERC20Registered(address indexed erc20, address indexed oracle, Treasury.AssetType assetType, Treasury.RiskLevel riskLevel);
    event ERC20Deregistered(address indexed erc20);
    event ERC20OracleUpdated(
        address indexed erc20,
        address oldOracle,
        address newOracle
    );
    event ERC20ListedAsBondable(address indexed erc20);
    event ERC20ListedAsRedeemable(address indexed erc20);
    event ERC20DelistedAsBondable(address indexed erc20);
    event ERC20DelistedAsRedeemable(address indexed erc20);
    event ERC20sBonded(
        address indexed who,
        address indexed erc20,
        uint kttsMinted
    );
    event ERC20sRedeemed(
        address indexed who,
        address indexed erc20,
        uint kttsBurned
    );

    // Constants copied from elastic-receipt-token.
    // For more info see elastic-receipt-token.
    uint internal constant MAX_SUPPLY = 1_000_000_000e18;

    function setUp() public {
        treasury = new Treasury();
    }

}
