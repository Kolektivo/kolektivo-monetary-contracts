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

    struct Vesting {
        uint start;
        uint end;
        uint totalAmount;
        uint alreadyReleased;
    }

    /// @dev Mapping of receiver address to Vesting struct array.
    mapping(address => Vesting[]) private vestings;

    //--------------------------------------------------------------------------
    // Modifiers

    modifier validReceiver(address receiver, uint amount, uint duration) {
        if(!_validReceiver(receiver)) {
            vm.expectRevert(Errors.InvalidRecipient);
            vestingVaultNejc.depositFor(receiver, amount, duration);
            return;
        }
        _;
    }

    modifier validAmount(address receiver, uint amount, uint duration) {
        if(!_validAmount(amount)) {
            vm.expectRevert(Errors.InvalidAmount);
            vestingVaultNejc.depositFor(receiver, amount, duration);
            return;
        }
        _;
    }

    modifier validDuration(address receiver, uint amount, uint duration) {
        if(!_validDuration(duration)) {
            vm.expectRevert(Errors.InvalidDuration);
            vestingVaultNejc.depositFor(receiver, amount, duration);
            return;
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Modifier functions

    // Expect revert if receiver is invalid.
    // Modifier: validRecipient.
    function _validReceiver(address receiver)
        internal
        view
        returns(bool)
    {
        return !(receiver == address(0)             ||
            receiver == address(vestingVaultNejc)   ||
            receiver == address(this)               ||
            receiver == address(token)
        );
    }

    // Expect revert if amount is zero or over 10e70.
    // Modifier: validAmount.
    function _validAmount(uint amount)
        internal
        pure
        returns(bool)
    {
        return !(amount == 0 || amount > 10e70);
    }

    // Expect revert if vestingDuration is zero or over 10e8.
    // Modifier: validDuration.
    function _validDuration(uint duration)
        internal
        pure
        returns(bool)
    {
        return !(duration == 0 || duration > 10e8);
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
        validReceiver(receiver, amount, duration)
        validAmount(receiver, amount, duration)
        validDuration(receiver, amount, duration)
    {
        depositFor(receiver, amount, duration);
    }

    //--------------------------------------------------------------------------
    // Claim Tests

    function testInstantClaim(address receiver, uint amount, uint duration)
        public
        validReceiver(receiver, amount, duration)
        validAmount(receiver, amount, duration)
        validDuration(receiver, amount, duration)
    {
        depositFor(receiver, amount, duration);

        uint claimable = vestingVaultNejc.getTotalClaimableFor(receiver);
        if (claimable == 0 ) {
            vm.expectRevert(Errors.InvalidVestingsData);
            vestingVaultNejc.claim();
            return;
        }

        assertEq(claimable, 0, "claimable amount should be zero");

        vestingVaultNejc.claim();
    }

    function testRandomClaim(address receiver, uint amount, uint duration, uint skipTime)
        public
        validReceiver(receiver, amount, duration)
        validAmount(receiver, amount, duration)
        validDuration(receiver, amount, duration)
    {
        vm.assume(skipTime < 10e70);
        depositFor(receiver, amount, duration);

        claim(receiver, skipTime);
    }

    function testSeveralClaims(
        address receiver,
        uint amount,
        uint duration,
        uint[] memory skipTimes,
        uint claimsAmount
    )
        public
        validReceiver(receiver, amount, duration)
        validAmount(receiver, amount, duration)
        validDuration(receiver, amount, duration)
    {
        vm.assume(claimsAmount < 10);
        vm.assume(skipTimes.length >= claimsAmount);

        depositFor(receiver, amount, duration);

        for(uint i; i < claimsAmount; i++) {
            vm.assume(skipTimes[i] < duration/2);

            claim(receiver, skipTimes[i]);
        }
    }

    // @notice stress test, heavy on resources
    function testSeveralRecipentsClaim(
        address[] memory receivers,
        uint receiversAmount,
        uint amount,
        uint duration,
        uint skipTime
    )
        public
    {
        vm.assume(_validAmount(amount));
        vm.assume(_validDuration(duration));

        receiversAmount = bound(receiversAmount, 2, 8);
        vm.assume(skipTime < type(uint64).max);
        vm.assume(receivers.length >= receiversAmount);

        for(uint i; i < receiversAmount; i++) {
            vm.assume(_validReceiver(receivers[i]));

            depositFor(receivers[i], amount, duration);
        }

        for(uint i; i < receiversAmount; i++) {
            claim(receivers[i], skipTime);
        }
    }

    // function testSeveralVestingsClaim(){}
    // ^already tested in testSeveralRecipentsClaim()

    //--------------------------------------------------------------------------
    // Helper Functions

    function depositFor(address receiver, uint amount, uint duration)
        public
    {
        // mint tokens for investor
        token.mint(address(this), amount);
        assertEq(token.balanceOf(address(this)), amount);

        // Otherwise expect tokens to be deposited.
        token.approve(address(vestingVaultNejc), amount);
        assertEq(token.allowance(address(this), address(vestingVaultNejc)), amount);

        uint vestedBefore = vestingVaultNejc.getTotalVestedFor(receiver);

        vestingVaultNejc.depositFor(receiver, amount, duration);

        // validate vesting data depositing tokens
        uint vestedAfter = vestingVaultNejc.getTotalVestedFor(receiver);
        assertEq(vestedBefore + amount, vestedAfter);

        Vesting memory vesting = Vesting(
            block.timestamp,                   // start
            block.timestamp + duration,        // end
            amount,                            // totalAmount
            0                                  // alreadyReleased
        );
        vestings[receiver].push(vesting);
    }

    function claim(address receiver, uint skipTime)
        public
    {
        uint balanceBefore = token.balanceOf(address(receiver));

        skip(skipTime);

        uint claimable = vestingVaultNejc.getTotalClaimableFor(receiver);
        if (claimable == 0 ) {
            vm.expectRevert(Errors.InvalidVestingsData);
            vestingVaultNejc.claim();
            return;
        }

        // @dev code is copied directly from program
        uint totalClaimable;
        for(uint i; i < vestings[receiver].length; i++) {
            Vesting memory vesting = vestings[receiver][i];

            if(vesting.alreadyReleased == 0 && block.timestamp > vesting.end){
                totalClaimable = totalClaimable + vesting.totalAmount;
                delete vestings[receiver][i];
            }
            else {
                uint timePassed = block.timestamp - vesting.start;
                uint totalDuration = vesting.end - vesting.start;
                uint claimableAmount;

                if(timePassed > totalDuration){
                    claimableAmount = vesting.totalAmount - vesting.alreadyReleased;
                }
                else{
                    claimableAmount = timePassed * vesting.totalAmount / totalDuration
                        - vesting.alreadyReleased;
                }

                vestings[receiver][i].alreadyReleased = vestings[receiver][i].alreadyReleased + claimableAmount;
                totalClaimable = totalClaimable + claimableAmount;

                if(vesting.alreadyReleased == vesting.totalAmount){
                    delete vestings[receiver][i];
                }

            }
        }

        vm.prank(receiver);
        vestingVaultNejc.claim();

        uint balanceAfter = token.balanceOf(address(receiver));

        assertEq(balanceBefore + totalClaimable, balanceAfter);

    }
}
