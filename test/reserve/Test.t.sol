// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC721Receiver} from "src/interfaces/_external/IERC721Receiver.sol";

import "src/Reserve.sol";

import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";
import {ERC721Mock} from "../utils/mocks/ERC721Mock.sol";
import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {TimeLockVaultMock} from "../utils/mocks/TimeLockVaultMock.sol";

/**
 * Errors library for Reserve's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/TSOwnable.sol.
    bytes internal constant OnlyCallableByOwner = abi.encodeWithSignature("OnlyCallableByOwner()");

    bytes internal constant InvalidRecipient = abi.encodeWithSignature("Reserve__InvalidRecipient()");

    bytes internal constant InvalidAmount = abi.encodeWithSignature("Reserve__InvalidAmount()");

    bytes internal constant ERC20NotRegistered = abi.encodeWithSignature("Reserve__ERC20NotRegistered()");

    bytes internal constant ERC721IdNotRegistered = abi.encodeWithSignature("Reserve__ERC721IdNotRegistered()");

    bytes internal constant ERC20NotBondable = abi.encodeWithSignature("Reserve__ERC20NotBondable()");

    bytes internal constant ERC721IdNotBondable = abi.encodeWithSignature("Reserve__ERC721IdNotBondable()");

    bytes internal constant ERC20NotRedeemable = abi.encodeWithSignature("Reserve__ERC20NotRedeemable()");

    bytes internal constant ERC721IdNotRedeemable = abi.encodeWithSignature("Reserve__ERC721NotRedeemable()");

    bytes internal constant ERC20BondingLimitExceeded = abi.encodeWithSignature("Reserve__ERC20BondingLimitExceeded()");

    bytes internal constant ERC20RedeemLimitExceeded = abi.encodeWithSignature("Reserve__ERC20RedeemLimitExceeded()");

    bytes internal constant ERC20BalanceNotSufficient = abi.encodeWithSignature("Reserve__ERC20BalanceNotSufficient()");

    bytes internal constant MinimumBackingLimitExceeded =
        abi.encodeWithSignature("Reserve__MinimumBackingLimitExceeded()");

    bytes internal constant InvalidOracle = abi.encodeWithSignature("Reserve__InvalidOracle()");
}

/**
 * @dev Root contract for Reserve Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
contract ReserveTest is Test, IERC721Receiver {
    // SuT.
    Reserve reserve;

    // Mocks.
    ERC20Mock token; // The reserve token
    OracleMock tokenOracle; // The reserve token's price oracle
    TimeLockVaultMock vestingVault;    // The vesting vault for ERC20 bondings
    ERC721Mock nft; // A ERC721 contract
    OracleMock defaultERC721IdOracle; // The default ERC721Id's price oracle

    // Test constants.
    uint256 constant DEFAULT_MIN_BACKING = 7_500; // 75%

    address DEFAULT_ERC721_ADDRESS;
    uint256 DEFAULT_ERC721_ID;

    // Copied from SuT.
    uint256 constant BPS = 10_000;

    function setUp() public {
        token = new ERC20Mock("RTKN", "Reserve Token", uint8(18));
        vestingVault = new TimeLockVaultMock();
        tokenOracle = new OracleMock();
        tokenOracle.setDataAndValid(1e18, true);


        // vestingVault = new VestingVaultMock(address(token));

        nft = new ERC721Mock();

        nft.mint(address(this), 1);
        DEFAULT_ERC721_ADDRESS = address(nft);
        DEFAULT_ERC721_ID = 1;
        defaultERC721IdOracle = new OracleMock();
        defaultERC721IdOracle.setDataAndValid(1e18, true);

        reserve = new Reserve(
            address(token),
            address(tokenOracle),
            address(vestingVault),
            DEFAULT_MIN_BACKING
        );
    }

    //--------------------------------------------------------------------------
    // IERC721

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
