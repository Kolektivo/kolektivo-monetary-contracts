// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Test.t.sol";

contract ReserveFractionalReserveBanking is ReserveTest {

    // Denomination is USD with 18 decimal precision.
    // Max price is defined as 1 billion USD.
    uint constant MAX_PRICE = 1_000_000_000 * 1e18;

    // Denomination is in USD with 18 decimal precision.
    // Max deposit value is defined as 1 billion USD.
    uint constant MAX_DEPOSIT_VALUE = 1_000_000_000 * 1e18;

    function testOvercollateralizedBacking() public {
        uint erc20Price = 10e18;      // 10 USD
        uint erc20Deposit = 1_000e18; // 1,000 erc20s
        // => ReserveValuation = 10,000 USD
        // => SupplyValuation  = 10,000 USD
        // => Backing          = 100%       = 10_000 bps

        // Setup an erc20 token and some initial backing.
        (ERC20Mock erc20, OracleMock erc20Oracle) = _setUpERC20(erc20Price);
        _setUpInitialBacking(erc20, erc20Deposit);

        // Mint some erc20 and send them to reserve.
        // => Increases ReserveValuation but keeps supplyValuation as is.
        erc20.mint((address(this)), erc20Deposit);
        erc20.transfer(address(reserve), erc20Deposit);

        // => ReserveValuation = 20,000 USD
        // => SupplyValuation  = 10,000 USD
        // => Backing          = 200%       = 20_000 bps
        _checkBacking(20_000e18, 10_000e18, 20_000);
    }

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
        _setUpInitialBacking(erc20, erc20Deposit);

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

    function testIncurDebt_NotAcceptedIf_MinBackingRequirementExceeded()
        public
    {
        uint erc20Price = 10e18;      // 10 USD
        uint erc20Deposit = 1_000e18; // 1,000 erc20s
        // => ReserveValuation = 10,000 USD
        // => SupplyValuation  = 10,000 USD
        // => Backing          = 100%

        // Setup an erc20 token and some initial backing.
        (ERC20Mock erc20, OracleMock erc20Oracle) = _setUpERC20(erc20Price);
        _setUpInitialBacking(erc20, erc20Deposit);

        uint tokenPrice = 1e18;       // 1 USD
        uint debtIncurred = 5_000e18; // 5,000 USD
        // => ReserveValuation = 10,000 USD
        // => SupplyValuation  = 15,000 USD
        // => Backing          = 6,666 bps ((10,000 * 100) / 15,000)
        // => Note that minBacking is 7,500 bps

        // Adjust token oracle to given price.
        tokenOracle.setDataAndValid(tokenPrice, true);

        vm.expectRevert(Errors.MinimumBackingLimitExceeded);
        reserve.incurDebt(debtIncurred);
    }

    //--------------------------------------------------------------------------
    // Un/Bonding Functions

    function testBondingAndRedeeming() public {
        // 1. Bond ERC20 with 18 decimal places.
        //
        uint erc20WadPrice = 100e18; // 100 USD
        uint erc20WadAmount = 100e18; // 10,000 USD
        ERC20Mock erc20Wad = new ERC20Mock("WAD", "Wad Token Mock", uint8(18));
        OracleMock oWad = new OracleMock();
        oWad.setDataAndValid(erc20WadPrice, true);

        // Set token's price to 1 USD.
        tokenOracle.setDataAndValid(1e18, true);

        // Mint and approve.
        erc20Wad.mint(address(this), erc20WadAmount);
        erc20Wad.approve(address(reserve), erc20WadAmount);

        // Register erc20 in reserve and list as bondable/redeemable.
        reserve.registerERC20(address(erc20Wad), address(oWad));
        reserve.listERC20AsBondable(address(erc20Wad));
        reserve.listERC20AsRedeemable(address(erc20Wad));

        // Bond erc20.
        reserve.bondERC20AllFromTo(address(erc20Wad), address(this), address(this));

        // Check balances.
        assertEq(erc20Wad.balanceOf(address(reserve)), erc20WadAmount);
        assertEq(erc20Wad.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(this)), 10_000 * 1e18); // 10,000 tokens

        // Check backing.
        _checkBacking(10_000e18, 10_000e18, BPS);

        // 2. Bond ERC20 with !18 decimal places.
        //
        uint8 erc20NonWadDecimals = 9;
        uint erc20NonWadPrice = 5e17;   // 0.5 USD
        uint erc20NonWadAmount = 100e9; // 50 USD
        ERC20Mock erc20NonWad = new ERC20Mock("NWAD", "Non-Wad Token Mock", erc20NonWadDecimals);
        OracleMock oNonWad = new OracleMock();
        oNonWad.setDataAndValid(erc20NonWadPrice, true);

        // Mint and approve.
        erc20NonWad.mint(address(this), erc20NonWadAmount);
        erc20NonWad.approve(address(reserve), erc20NonWadAmount);

        // Register erc20 in reserve and list as bondable/redeemable.
        reserve.registerERC20(address(erc20NonWad), address(oNonWad));
        reserve.listERC20AsBondable(address(erc20NonWad));
        reserve.listERC20AsRedeemable(address(erc20NonWad));

        // Bond erc20.
        reserve.bondERC20AllFromTo(address(erc20NonWad), address(this), address(this));

        // Check balances.
        assertEq(erc20NonWad.balanceOf(address(reserve)), erc20NonWadAmount);
        assertEq(erc20NonWad.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(this)), (10_000 + 50) * 1e18); // 10,050 tokens

        // Check backing.
        _checkBacking(10_050e18, 10_050e18, BPS);

        // 3. Bond ERC721Id instance.
        //
        defaultERC721IdOracle.setDataAndValid(1_000_000e18, true); // 1MM USD

        // Approve.
        nft.approve(address(reserve), DEFAULT_ERC721ID.id);

        // Register erc721Id in reserve and list as bondable/redeemable.
        reserve.registerERC721Id(DEFAULT_ERC721ID, address(defaultERC721IdOracle));
        reserve.listERC721IdAsBondable(DEFAULT_ERC721ID);
        reserve.listERC721IdAsRedeemable(DEFAULT_ERC721ID);

        // Bond erc721Id.
        reserve.bondERC721IdFromTo(DEFAULT_ERC721ID, address(this), address(this));

        // Check balances.
        assertEq(nft.ownerOf(DEFAULT_ERC721ID.id), address(reserve));
        assertEq(token.balanceOf(address(this)), (10_000 + 50 + 1_000_000) * 1e18); // 1MM + 10,050 tokens

        // Check backing.
        _checkBacking(1_010_050e18, 1_010_050e18, BPS);

        // 4. Change token's price by -50%.
        //
        // Note that the reserve's backing ratio is now 200%.
        tokenOracle.setDataAndValid(5e17, true); // 0.5 USD

        // 5. Redeem the erc20Wad tokens.
        //
        // Note that the token price contracted by 50%.
        // Therefore, we only receive half the erc20Wad tokens for the same 10k tokens
        // we received for bonding the whole erc20Wad amount.
        reserve.redeemERC20(address(erc20Wad), 10_000e18);

        // Check balances.
        assertEq(erc20Wad.balanceOf(address(reserve)), erc20WadAmount / 2);
        assertEq(erc20Wad.balanceOf(address(this)), erc20WadAmount / 2);
        assertEq(token.balanceOf(address(this)), (50 + 1_000_000) * 1e18);

        // 6. Change token's price back to initial.
        //
        // Note that we could not unbond the erc721Id otherwise.
        tokenOracle.setDataAndValid(1e18, true); // 1 USD

        // 7. Redeem the erc721Id instance.
        reserve.redeemERC721IdFromTo(DEFAULT_ERC721ID, address(this), address(this));

        // Check balances.
        assertEq(nft.ownerOf(DEFAULT_ERC721ID.id), address(this));
        assertEq(token.balanceOf(address(this)), 50 * 1e18);

        // 7. Redeem the erc20NonWad tokens.
        reserve.redeemERC20AllFromTo(address(erc20NonWad), address(this), address(this));

        // Check balances.
        assertEq(erc20NonWad.balanceOf(address(reserve)), 0);
        assertEq(erc20NonWad.balanceOf(address(this)), erc20NonWadAmount);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testBondingAndRedeemingWithBondingDiscountsAndBondingVesting()
        public
    {
        // Note that the test is copied from the above one.
        // A discount is added to the erc20Wad token and erc721Id instance, and
        // the expected token amounts are adjusted.

        // 1. Bond ERC20 with 18 decimal places and discount of 10%.
        //
        uint erc20WadPrice = 100e18; // 100 USD
        uint erc20WadAmount = 100e18; // 10,000 USD
        ERC20Mock erc20Wad = new ERC20Mock("WAD", "Wad Token Mock", uint8(18));
        OracleMock oWad = new OracleMock();
        oWad.setDataAndValid(erc20WadPrice, true);

        // Set token's price to 1 USD.
        tokenOracle.setDataAndValid(1e18, true);

        // Mint and approve.
        erc20Wad.mint(address(this), erc20WadAmount);
        erc20Wad.approve(address(reserve), erc20WadAmount);

        // Register erc20 in reserve and list as bondable/redeemable.
        reserve.registerERC20(address(erc20Wad), address(oWad));
        reserve.listERC20AsBondable(address(erc20Wad));
        reserve.listERC20AsRedeemable(address(erc20Wad));

        // Set discount of 10%.
        reserve.setBondingDiscountForERC20(address(erc20Wad), 1_000); // 1,000 bps = 10%

        // Bond erc20.
        reserve.bondERC20AllFromTo(address(erc20Wad), address(this), address(this));

        // Check balances.
        assertEq(erc20Wad.balanceOf(address(reserve)), erc20WadAmount);
        assertEq(erc20Wad.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(this)), 11_000 * 1e18); // 11,000 tokens

        // Check backing.
        uint expectedBacking = (10_000 * BPS) / 11_000; // = 9,090 bps = 90.90%
        _checkBacking(10_000e18, 11_000e18, expectedBacking);

        // 2. Bond ERC20 with !18 decimal places and vested.
        //
        uint8 erc20NonWadDecimals = 9;
        uint erc20NonWadPrice = 5e17;   // 0.5 USD
        uint erc20NonWadAmount = 100e9; // 50 USD
        ERC20Mock erc20NonWad = new ERC20Mock("NWAD", "Non-Wad Token Mock", erc20NonWadDecimals);
        OracleMock oNonWad = new OracleMock();
        oNonWad.setDataAndValid(erc20NonWadPrice, true);

        // Mint and approve.
        erc20NonWad.mint(address(this), erc20NonWadAmount);
        erc20NonWad.approve(address(reserve), erc20NonWadAmount);

        // Register erc20 in reserve and list as bondable/redeemable.
        reserve.registerERC20(address(erc20NonWad), address(oNonWad));
        reserve.listERC20AsBondable(address(erc20NonWad));
        reserve.listERC20AsRedeemable(address(erc20NonWad));

        // Set vesting of 1 hour.
        reserve.setBondingVestingForERC20(address(erc20NonWad), 1 hours);

        // Bond erc20.
        reserve.bondERC20AllFromTo(address(erc20NonWad), address(this), address(this));

        // Check balances.
        assertEq(erc20NonWad.balanceOf(address(reserve)), erc20NonWadAmount);
        assertEq(erc20NonWad.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(this)), 11_000 * 1e18); // 10,000 tokens
        assertEq(token.balanceOf(address(vestingVault)), 50 * 1e18); // 50 tokens

        // Check backing.
        expectedBacking = (10_050 * BPS) / 11_050;
        _checkBacking(10_050e18, 11_050e18, expectedBacking); // 9,095 bps = 90.95%

        // Wait for 1 hour and claim tokens from vesting vault.
        vm.warp(block.timestamp + 1 hours);
        vestingVault.claim();

        // 3. Bond ERC721Id instance with discount.
        //
        defaultERC721IdOracle.setDataAndValid(1_000_000e18, true); // 1MM USD

        // Approve.
        nft.approve(address(reserve), DEFAULT_ERC721ID.id);

        // Register erc721Id in reserve and list as bondable/redeemable.
        reserve.registerERC721Id(DEFAULT_ERC721ID, address(defaultERC721IdOracle));
        reserve.listERC721IdAsBondable(DEFAULT_ERC721ID);
        reserve.listERC721IdAsRedeemable(DEFAULT_ERC721ID);

        // Set discount of 5%.
        reserve.setBondingDiscountForERC721Id(DEFAULT_ERC721ID, 500); // 500 bps = 5%

        // Bond erc721Id.
        reserve.bondERC721IdFromTo(DEFAULT_ERC721ID, address(this), address(this));

        // Check balances.
        assertEq(nft.ownerOf(DEFAULT_ERC721ID.id), address(reserve));
        assertEq(token.balanceOf(
            address(this)),
            (11_000 + 50 + 1_000_000 + 50_000) * 1e18 // 11,050 tokens + 1MM + 5% of 1 MM
        );

        // Check backing.
        expectedBacking = (1_010_050 * BPS) / 1_061_050; // 9,519 bps = 95.19%
        _checkBacking(1_010_050e18, 1_061_050e18, expectedBacking);
    }

    //--------------------------------------------------------------------------
    // Internal Functions

    function _setUpInitialBacking(ERC20Mock erc20, uint amount)
        internal
    {
        erc20.mint(address(this), amount);

        erc20.approve(address(reserve), amount);
        reserve.bondERC20(address(erc20), amount);
    }

    function _setUpERC20(uint price) internal returns (ERC20Mock, OracleMock) {
        ERC20Mock erc20 = new ERC20Mock("TKN", "Token Mock", uint8(18));
        OracleMock o = new OracleMock();
        o.setDataAndValid(price, true);

        // Register erc20 in reserve.
        reserve.registerERC20(address(erc20), address(o));

        // List erc20 as bondable/redeemable.
        reserve.listERC20AsBondable(address(erc20));
        reserve.listERC20AsRedeemable(address(erc20));

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

}
