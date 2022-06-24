// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/Reserve2.sol";

import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";
import {ERC721Mock} from "../utils/mocks/ERC721Mock.sol";
import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {VestingVaultMock} from "../utils/mocks/VestingVaultMock.sol";

/**
 * Errors library for Reserve2's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    // Inherited from solrocket/Ownable.sol.
    bytes internal constant OnlyCallableByOwner
        = abi.encodeWithSignature("OnlyCallableByOwner()");

    bytes internal constant InvalidRecipient
        = abi.encodeWithSignature("Reserve2__InvalidRecipient()");

    bytes internal constant InvalidAmount
        = abi.encodeWithSignature("Reserve2__InvalidAmount()");

    bytes internal constant ERC20NotSupported
        = abi.encodeWithSignature("Reserve2__ERC20NotSupported()");

    bytes internal constant ERC721IdNotSupported
        = abi.encodeWithSignature("Reserve2__ERC721IdNotSupported()");

}

/**
 * @dev Root contract for Reserve2 Test Contracts.
 *
 *      Provides setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
contract Reserve2Test is Test {

    // SuT.
    Reserve2 reserve;

    // Mocks.
    ERC20Mock token;                  // The reserve token
    OracleMock tokenOracle;           // The reserve token's price oracle
    VestingVaultMock vestingVault;    // The vesting vault for ERC20 bondings
    ERC721Mock nft;                   // A ERC721 contract
    OracleMock defaultERC721IdOracle; // The default ERC721Id's price oracle

    // Test constants.
    uint constant DEFAULT_MIN_BACKING = 7_500; // 75%

    IReserve2.ERC721Id DEFAULT_ERC721ID;

    // Copied from SuT.
    uint constant BPS = 10_000;

    function setUp() public {
        token = new ERC20Mock("RTKN", "Reserve Token", uint8(18));

        tokenOracle = new OracleMock();
        tokenOracle.setDataAndValid(1e18, true);

        vestingVault = new VestingVaultMock(address(token));

        nft = new ERC721Mock();

        nft.mint(address(this), 1);
        DEFAULT_ERC721ID = IReserve2.ERC721Id(address(nft), 1);
        defaultERC721IdOracle = new OracleMock();
        tokenOracle.setDataAndValid(1e18, true);

        reserve = new Reserve2(
            address(token),
            address(tokenOracle),
            address(vestingVault),
            DEFAULT_MIN_BACKING
        );
    }

}
