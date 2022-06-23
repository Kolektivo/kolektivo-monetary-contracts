// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/Reserve2.sol";

import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";
import {OracleMock} from "../utils/mocks/OracleMock.sol";
import {VestingVaultMock} from "../utils/mocks/VestingVaultMock.sol";

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
    ERC20Mock token;               // The reserve token.
    OracleMock tokenOracle;        // The reserve token's price oracle.
    VestingVaultMock vestingVault; // The vesting vault for ERC20 bondings.

    // Test constants.
    uint constant DEFAULT_MIN_BACKING = 7_500; // 75%

    function setUp() public {
        token = new ERC20Mock("RTKN", "Reserve Token", uint8(18));

        tokenOracle = new OracleMock();
        tokenOracle.setDataAndValid(1e18, true);

        vestingVault = new VestingVaultMock(address(token));

        reserve = new Reserve2(
            address(token),
            address(tokenOracle),
            address(vestingVault),
            DEFAULT_MIN_BACKING
        );
    }

    function testPass() public {
        require(true);
    }

}
