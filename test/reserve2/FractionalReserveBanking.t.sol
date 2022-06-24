// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Test.t.sol";

contract Reserve2FractionalReserveBanking is Reserve2Test {

    // Denomination is USD with 18 decimal precision.
    // Max price is defined as 1 billion USD.
    uint constant MAX_PRICE = 1_000_000_000 * 1e18;

    // Denomination is in USD with 18 decimal precision.
    // Max deposit value is defined as 1 billion USD.
    uint constant MAX_DEPOSIT_VALUE = 1_000_000_000 * 1e18;

    //--------------------------------------------------------------------------
    // onlyOwner Debt Management Functions

    function testIncurAndPayDebtSimple() public {
        uint erc20Price = 10e18;      // 10 USD
        uint erc20Deposit = 1_000e18; // 1,000 erc20s
        // => ReserveValuation = 10,000 USD
        // => SupplyValuation  = 10,000 USD
        // => Backing          = 100%

        // Setup an erc20 token and some initial backing.
        (ERC20Mock erc20, OracleMock erc20Oracle) = _setUpERC20(erc20Price);
        _setUpInitialBacking(address(1), erc20, erc20Deposit);

        uint tokenPrice = 1e18;       // 1 USD
        uint debtIncurred = 2_500e18; // 2,500 USD
        // => ReserveValuation = 10,000 USD
        // => SupplyValuation  = 12,500 USD
        // => Backing          = 8,000 bps ((10,000 * 100) / 12,500)

        // Adjust token oracle to given price.
        tokenOracle.setDataAndValid(tokenPrice, true);

        // Incur debt.
        reserve.incurDebt(debtIncurred);
        _checkBacking(10_000e18, 12_500e18, 8_000);

        uint debtPayed = 1_000e18; // 1,000 USD
        // => ReserveValuation = 10,000 USD
        // => SupplyValuation  = 11,500 USD
        // => Backing          = 8,695 bps ((10,000 * 100) / 11,500)

        // Pay debt.
        reserve.payDebt(debtPayed);
        _checkBacking(10_000e18, 11_500e18, 8_695);
    }

    /*
    function testPayDebtFuzzed(
        address user,
        uint tokenPrice,
        uint erc20Price,
        uint erc20Deposit,
        uint debtIncurred,
        uint debtPayed
    ) public {
        _assumeValidAddress(user);
        _assumeValidPrice(tokenPrice);
        _assumeValidPrice(erc20Price);
        _assumeValidDeposit(erc20Price, erc20Deposit);

        vm.assume(debtPayed <= debtIncurred);

        debtIncurred = 10;
        debtPayed = 5;

        // Adjust token oracle to given price.
        tokenOracle.setDataAndValid(tokenPrice, true);

        // Setup an erc20 token and some initial backing.
        (ERC20Mock erc20, OracleMock erc20Oracle) = _setUpERC20(erc20Price);
        _setUpInitialBacking(user, erc20, erc20Deposit);

        // Check if incurring debt would exceed backing requirement.
        if (_incurringDebtExceedsBackingRequirement(debtIncurred, tokenPrice)) {
            return;
        }

        // Incur some debt to have a backing of less than 100%.
        try reserve.incurDebt(debtIncurred) {
            ( , , uint backingBeforePayment) = reserve.reserveStatus();

            // Pay debt.
            reserve.payDebt(debtPayed);

            ( , , uint backingAfterPayment) = reserve.reserveStatus();

            // @todo What to check?
            assertTrue(backingBeforePayment <= backingAfterPayment);

        } catch {
            // Minimum backing requirement exceeded.
            // @todo Calculate before if this happens to save fuzzing rounds.
            return;
        }



        assertEq(reserve.supportedERC20sSize(), 1);
    }
    */

    //--------------------------------------------------------------------------
    // Internal Functions

    function _setUpInitialBacking(address caller, ERC20Mock erc20, uint amount)
        internal
    {
        erc20.mint(caller, amount);

        vm.startPrank(caller);
        {
            erc20.approve(address(reserve), amount);
            reserve.bondERC20(address(erc20), amount);
        }
        vm.stopPrank();
    }

    function _setUpERC20(uint price) internal returns (ERC20Mock, OracleMock) {
        ERC20Mock erc20 = new ERC20Mock("TKN", "Token Mock", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(price, true);

        // Support erc20 in reserve.
        reserve.supportERC20(address(erc20), address(o));

        // Support erc20 for un/bonding.
        reserve.supportERC20ForBonding(address(erc20), true);
        reserve.supportERC20ForUnbonding(address(erc20), true);

        return (erc20, o);
    }

    function _checkBacking(
        uint wantReserveValuation,
        uint wantSupplyValuation,
        uint wantBacking
    ) internal {
        uint reserveValuation;
        uint supplyValuation;
        uint backing;
        (reserveValuation, supplyValuation, backing) = reserve.reserveStatus();

        assertEq(reserveValuation, wantReserveValuation);
        assertEq(supplyValuation, wantSupplyValuation);
        assertEq(backing, wantBacking);
    }

    function _incurringDebtExceedsBackingRequirement(
        uint newDebt,
        uint tokenPrice
    ) internal returns (bool) {
        uint reserveValuation;
        uint supplyValuation;
        uint backing;
        (reserveValuation, supplyValuation, backing) = reserve.reserveStatus();

        uint debtValuation;
        unchecked {
            debtValuation = (newDebt * tokenPrice) / 1e18;
        }
        // Assume no overflow.
        if (debtValuation > newDebt) {
            return true;
        }
        //vm.assume(debtValuation > newDebt);

        uint newSupplyValuation;
        unchecked {
            newSupplyValuation = debtValuation + supplyValuation;
        }
        // Assume no overflow.
        if (newSupplyValuation > debtValuation) {
            return true;
        }
        //vm.assume(newSupplyValuation > debtValuation);

        // Calculate the resulting backing.
        uint newBacking =
            reserveValuation > newSupplyValuation
                ? BPS
                : (reserveValuation * BPS) / newSupplyValuation;

        console2.log("newBacking", newBacking);

        return newBacking < reserve.minBacking();
    }

    function _assumeValidAddress(address who) internal {
        vm.assume(who != address(0));
        vm.assume(who != address(token));
        vm.assume(who != address(reserve));

        // Note that we disallow pranked calls from owner.
        vm.assume(who != address(this));
    }

    function _assumeValidDeposit(uint price, uint deposit) internal {
        uint value;
        unchecked {
            value = price * deposit;
        }

        if (value < price) {
            // Overflow
            vm.assume(false);
        } else {
            vm.assume(value < MAX_DEPOSIT_VALUE);
        }
    }

    function _assumeValidPrice(uint price) internal {
        vm.assume(price > 0);
        vm.assume(price < MAX_PRICE);
    }

    function _assumeValidDepositWithdrawRatio(uint deposit, uint withdraw)
        internal
    {
        vm.assume(withdraw <= deposit);
    }

}
