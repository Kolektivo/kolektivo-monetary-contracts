// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "src/vesting/VestingVaultNejc.sol";

import {ERC20Mock} from "../utils/mocks/ERC20Mock.sol";



/**
 * Errors library for VestingVaultNejc's custom errors.
 * Enables checking for errors with vm.expectRevert(Errors.<Error>).
 */
library Errors {
    bytes internal constant InvalidRecipient =
        abi.encodeWithSignature("InvalidRecipient()");

    bytes internal constant InvalidAmount =
        abi.encodeWithSignature("InvalidAmount()");

    bytes internal constant InvalidDuration =
        abi.encodeWithSignature("InvalidDuration()");

    bytes internal constant InvalidVestingsData =
        abi.encodeWithSignature("InvalidVestingsData()");
}

/**
 * @dev Root contract for VestingVaultNejc Test Contracts.
 *
 *      Provides the setUp functions, access to common test utils and internal
 *      variables used throughout testing.
 */
contract VestingVaultNejcTest is Test {
    // SuT.
    ERC20Mock token;
    VestingVaultNejc vestingVaultNejc;

    // Event copied from SuT.
    // Note that the Event declarations are needed to test for emission.
    event DepositFor(address indexed investor, address indexed receiver, uint amount, uint duration);
    event Claim(address indexed receiver, uint withdrawnAmount);

    // Token contructor arguments.
    string internal constant NAME = "testToken";
    string internal constant SYMBOL = "TT";
    uint internal constant DECIMALS = 18;

    //--------------------------------------------------------------------------
    // Modifiers

    modifier validParams(address receiver, uint amount, uint duration) {
        // Expect revert if receiver is invalid.
        // Modifier: validRecipient.
        if (receiver == address(0)                  ||
            receiver == address(vestingVaultNejc)   ||
            receiver == address(this)               ||
            receiver == address(token)
        ) {
            vm.expectRevert(Errors.InvalidRecipient);
            vestingVaultNejc.depositFor(receiver, amount, duration);
            return;
        }
        //
        // // Expect revert if amount is zero.
        // // Modifier: validAmount.
        if (amount == 0) {
            vm.expectRevert(Errors.InvalidAmount);
            vestingVaultNejc.depositFor(receiver, amount, duration);
            return;
        }

        // Expect revert if vestingDuration is zero.
        // Modifier: validVestingDuration.
        if (duration == 0 || duration > 10e8) {
            vm.expectRevert(Errors.InvalidDuration);
            vestingVaultNejc.depositFor(receiver, amount, duration);
            return;
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Set Up Functions

    function setUp() public {
        // contracts deployment
        token = new ERC20Mock(NAME, SYMBOL, uint8(DECIMALS));
        vestingVaultNejc = new VestingVaultNejc(address(token));
    }

    //--------------------------------------------------------------------------
    // Deployment Tests

    // function testDeploymentInvariants() public {
    function testDeploymentConstructor() public {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), DECIMALS);
        assertEq(vestingVaultNejc.token(), address(token));
    }

    //--------------------------------------------------------------------------
    //Deposit Tests

    function testDepositFor(address receiver, uint amount, uint duration)
        public
        validParams(receiver, amount, duration)
    {
        // mint tokens for investor
        token.mint(address(this), amount);
        assertEq(token.balanceOf(address(this)), amount);

        // Otherwise expect tokens to be deposited.
        token.approve(address(vestingVaultNejc), amount);
        assertEq(token.allowance(address(this), address(vestingVaultNejc)), amount);

        vestingVaultNejc.depositFor(receiver, amount, duration);


        // Check vestingVaultNejc balances
        assertEq(token.balanceOf(address(vestingVaultNejc)), amount);
        // TODO check emitted event

        // validate vesting data depositing tokens
        uint totalVested = vestingVaultNejc.getTotalVestedFor(receiver);
        assertEq(totalVested, amount);
    }


    // validate vesting data depositing tokens
    // function vestingDataIsCorrect(address receiver, uint amount, uint duration)
    //     internal
    // {
    //     // deposited amount is stored properly.
    //     uint totalVested = vestingVaultNejc.getTotalVestedFor(receiver);
    //     assertEq(totalVested, amount);
    // }

    //--------------------------------------------------------------------------
    // Claim Tests

    function testClaim(address receiver, uint amount, uint duration)
        public
        validParams(receiver, amount, duration)
    {
        testDepositFor(receiver, amount, duration);

        uint claimable = vestingVaultNejc.getTotalClaimableFor(receiver);
        if (claimable == 0 ) {
            vm.expectRevert(Errors.InvalidVestingsData);
            vestingVaultNejc.claim();
            return;
        }

        vestingVaultNejc.claim();

        // uint claimedAmount = testToken.balanceOf(receiver);
        // uint notYetClaimable = vestingVaultNejc.getTotalNotClaimableYetFor(receiver);
        // assertEq(claimedAmount + notYetClaimable, amount)
        //


        // Check vestingVaultNejc balances
        // assertEq(testToken.balanceOf(vestingVaultNejc), amount);
        // // TODO check that event is emitted
        //
        // uint totalVested = vestingVaultNejc.getTotalVestedFor(receiver);
        // assertEq(totalVested, amount);
        //
        // uint totalClaimable = vestingVaultNejc.getTotalNotClaimableYetFor(receiver);
        // //      assert totalClaimable < totalVested
        //
        // uint totalNotClaimableYetFor = vestingVaultNejc.getTotalNotClaimableYetFor(receiver);
        //      assert totalClaimable < totalNonClaimable

        // TODO after vesting is complete, make sure its not possible to claim anymore
        //
        // TODO make sure event is emitted
    }

}
