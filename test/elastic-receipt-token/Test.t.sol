// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/ElasticReceiptToken.sol";

import {ElasticReceiptTokenMock} from "../utils/mocks/ElasticReceiptTokenMock.sol";
import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";

/**
 * @dev Root contract for ElasticReceiptToken Test Contracts.
 *
 *      Provides the setUp function, access to common test utils and internal
 *      constants from the ElasticReceiptToken.
 */
abstract contract ElasticReceiptTokenTest is Test {
    // SuT
    ElasticReceiptTokenMock ert;

    // Mocks
    ERC20Mock underlier;

    // Constants
    string internal constant NAME = "elastic receipt Token";
    string internal constant SYMBOL = "ERT";
    uint256 internal constant DECIMALS = 9;

    // Constants copied from SuT.
    uint256 internal constant MAX_UINT = type(uint256).max;
    uint256 internal constant MAX_SUPPLY = 1_000_000_000e18;
    uint256 internal constant TOTAL_BITS = MAX_UINT - (MAX_UINT % MAX_SUPPLY);
    uint256 internal constant BITS_PER_UNDERLYING = TOTAL_BITS / MAX_SUPPLY;

    function setUp() public {
        underlier = new ERC20Mock("Test ERC20", "TEST", uint8(18));

        ert = new ElasticReceiptTokenMock(
            address(underlier),
            NAME,
            SYMBOL,
            uint8(DECIMALS)
        );
    }

    modifier assumeTestAmount(uint256 amount) {
        vm.assume(amount != 0 && amount <= MAX_SUPPLY);
        _;
    }

    modifier assumeTestAddress(address who) {
        vm.assume(who != address(0));
        vm.assume(who != address(ert));
        _;
    }

    function mintToUser(address user, uint256 erts) public {
        underlier.mint(user, erts);

        vm.startPrank(user);
        {
            underlier.approve(address(ert), type(uint256).max);
            ert.mint(erts);
        }
        vm.stopPrank();
    }

    function underflows(uint256 a, uint256 b) public pure returns (bool) {
        unchecked {
            uint256 x = a - b;
            return x > a;
        }
    }
}
