// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "solrocket/Ownable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

import {Treasury} from "./Treasury.sol";

import {KOL} from "./KOL.sol";

contract Reserve is Ownable, Whitelisted {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Supply can not be increased due to exceeding the reserve limit.
    /// @param backingInBPS The backing of supply in bps.
    /// @param minBackingInBPS The min amount of backing allowed, in bps.
    error SupplyExceedsReserveLimit(uint backingInBPS, uint minBackingInBPS);

    //--------------------------------------------------------------------------
    // Events

    // @todo Should events be KTT or KOL denominated?

    event BackingInBPSChanged(uint oldBackingInBPS, uint newBackingInBPS);

    //----------------------------------
    // Owner Events

    event MinBackingInBPSChanged(uint oldMinBackingInBPS,
                                 uint newMinBackingInBPS);

    event IncurredDebt(address indexed who, uint ktts);

    event PayedDebt(address indexed who, uint ktts);

    //----------------------------------
    // User Events

    event Deposit(address indexed who, uint ktts);

    event Withdrawal(address indexed who, uint ktts);

    //--------------------------------------------------------------------------
    // Modifiers

    //--------------------------------------------------------------------------
    // Constants

    /// @dev 10,000 bps are 100%.
    uint private constant BPS = 10_000;

    /// @dev The min amount in bps of reserve to supply.
    uint private constant MIN_BACKING_IN_BPS = 5_000; // 50%

    // @todo This is wrong! KTT uses 18 decimals!
    uint private constant KTT_DECIMALS = 9;
    uint private constant KOL_DECIMALS = 18;

    //--------------------------------------------------------------------------
    // Storage

    /// @dev The KOL token address.
    KOL private immutable _kol;

    /// @dev The KTT token address.
    ERC20 private immutable _ktt;

    /// @dev The bps of supply backed by the reserve.
    uint private _backingInBPS;

    /// @notice The min amount in bps of reserve to supply.
    /// @dev Changeable by owner.
    uint public minBackingInBPS;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(
        address kol_,
        address ktt_,
        uint minBackingInBPS_
    ) {
        require(kol_ != address(0));
        require(ktt_ != address(0));
        require(minBackingInBPS_ >= MIN_BACKING_IN_BPS);

        _kol = KOL(kol_);
        _ktt = ERC20(ktt_);
        minBackingInBPS = minBackingInBPS_;

        // Set current backing to 100%.
        _backingInBPS = BPS;
    }

    //--------------------------------------------------------------------------
    // User Mutating Functions

    /// @notice Deposits KTT tokens from msg.sender and mints corresponding KOL
    ///         tokens to msg.sender.
    /// @param ktts The amount of KTT tokens to deposit.
    function deposit(uint ktts)
        external
        onlyWhitelisted
    {
        _ktt.safeTransferFrom(msg.sender, address(this), ktts);

        uint kols = kttToKol(ktts);
        _kol.mint(msg.sender, kols);

        // @todo Not strictly necessary. But why not use the chance?
        //       Or better create backend task to call function regularly?
        _updateBackingInBPS();

        emit Deposit(msg.sender, ktts);
    }

    /// @notice Withdraws KTT tokens to msg.sender and burns KOL tokens from
    ///         msg.sender.
    /// @param kols The amount of KOL tokens to burn.
    function withdraw(uint kols)
        external
        onlyWhitelisted
    {
        uint ktts = kolToKtt(kols);
        _ktt.safeTransfer(msg.sender, ktts);

        _kol.burn(msg.sender, kols);

        // @todo See function deposit.
        _updateBackingInBPS();

        emit Withdrawal(msg.sender, ktts);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Debt Management

    function setMinBackingInBPS(uint minBackingInBPS_) external onlyOwner {
        require(minBackingInBPS_ >= MIN_BACKING_IN_BPS);

        // Only emit event is state changed.
        if (minBackingInBPS == minBackingInBPS_) {
            return;
        }

        emit MinBackingInBPSChanged(minBackingInBPS, minBackingInBPS_);

        minBackingInBPS = minBackingInBPS_;
    }

    function incurDebt(uint ktts)
        external
        onlyOwner
    {
        // Note to not create debt without any reserve backing.
        require(_reserveAdjusted() != 0);

        // @todo Emit event, adjust tests.

        // Note that this function is KTT denominated!
        uint kols = kttToKol(ktts);

        _kol.mint(msg.sender, kols);

        _updateBackingInBPS();

        // Revert if supply exceeds reserve's backing limit.
        if (_backingInBPS < minBackingInBPS) {
            revert SupplyExceedsReserveLimit(_backingInBPS, minBackingInBPS);
        }
    }

    function payDebt(uint kols)
        external
        onlyOwner
    {
        _kol.burn(msg.sender, kols);

        // @todo Emit event, adjust tests.

        _updateBackingInBPS();

        // @todo Rewrite
        // Note that min backing is not checked. Otherwise this would make it
        // impossible to pay debt back if KTT supply contracted to below min
        // backing level with the debt not paying it back fully.
    }

    //----------------------------------
    // Whitelist Management

    /// @notice Adds an address to the whitelist.
    /// @dev Only callable by owner.
    /// @param who The address to add to the whitelist.
    function addToWhitelist(address who) external onlyOwner {
        super._addToWhitelist(who);
    }

    /// @notice Removes an address from the whitelist.
    /// @dev Only callable by owner.
    /// @param who The address to remove from the whitelist.
    function removeFromWhitelist(address who) external onlyOwner {
        super._removeFromWhitelist(who);
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @notice Returns the KOL token address, i.e. the token created by this
    ///         reserve.
    function kol() external view returns (address) {
        return address(_kol);
    }

    /// @notice Returns the KTT token address, i.e. the token the reserve is
    ///         composed off.
    function ktt() external view returns (address) {
        return address(_ktt);
    }

    /// @notice Returns the current reserve status.
    /// @return uint: Reserve denominated in USD with 18 decimal precision.
    ///         uint: Supply denominated in USD with 18 decimal precision.
    ///         uint: Bps of supply backed by reserve.
    function reserveStatus() external view returns (uint, uint, uint) {
        return (_reserveAdjusted(), _supply(), _backingInBPS);
    }

    //--------------------------------------------------------------------------
    // Private Functions

    /// @dev Updates the bps of supply that is backed by the reserve.
    function _updateBackingInBPS() private {
        uint reserveAdjusted = _reserveAdjusted();
        uint supply = _supply();

        uint newBackingInBPS =
            reserveAdjusted >= supply
                ? BPS                               // Fully backed
                : (reserveAdjusted * BPS) / supply; // Partially backed

        emit BackingInBPSChanged(_backingInBPS, newBackingInBPS);

        _backingInBPS = newBackingInBPS;
    }

    /// @dev Returns the current reserve in USD denomination with 18 decimal
    ///      precision.
    function _reserveAdjusted() private view returns (uint) {
        // Note to convert reserve (KTT) to 18 decimals.
        return kttToKol(_ktt.balanceOf(address(this)));
    }

    /// @dev Returns the current supply in USD denomination with 18 decimal
    ///      precision.
    function _supply() private view returns (uint) {
        return _kol.totalSupply();
    }

    // @todo Propably uneccessary. KTT uses 18 decimals!

    // Note that KOL and KTT have different precision decimals.
    function kolToKtt(uint kols) private pure returns (uint) {
        // @todo Assumes KOL should be 1 USD.
        // @todo Can lead to zero! Be careful.
        //       -> Remove comment if tests implemented to specify behaviour.
        //       -> require(kols >= 1e9)?
        return kols / 1e9;
    }

    // Note that KOL and KTT have different precision decimals.
    function kttToKol(uint ktts) private pure returns (uint) {
        // @todo Assumes KOL should be 1 USD.
        return ktts * 1e9;
    }

}
