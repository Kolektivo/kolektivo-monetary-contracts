// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import "./Test.t.sol";

/**
 * @dev Discount Zapper Functions Tests.
 */
contract ReserveOnlyDiscountZapper is ReserveTest {

    function testOnlyDiscountZapperFunctionsNotPubliclyCallable(address caller)
        public
    {
        vm.assume(caller != reserve.discountZapper());

        vm.startPrank(caller);

        vm.expectRevert(Errors.OnlyCallableByDiscountZapper);
        reserve.depositAllWithDiscountFor(address(1), 10);
    }

    // @todo Rename test
    function testDepositDiscountZapper() public {
        // @todo Implement test.
        emit log_string("Not yet implemented");
    }

}
