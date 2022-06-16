// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {TSOwnable} from "solrocket/TSOwnable.sol";

interface ITreasury {
    function bond(address asset, uint amount) external;
    function isSupportedForBonding(address asset) external returns (bool);
}

interface IReserve {
    function depositAllWithDiscountFor(address to, uint discount) external;
}

/**
 * @title Discount Zapper
 *
 * @dev Zapper contract enabling depositing assets in the treasury and
 *      receiving KOL tokens from the reserve.
 *
 *      Discounts can be set on a per-asset basis by the contract's owner.
 *
 *      Note that this Zapper contract has a priviledged role in the reserve
 *      by being able to mint KOL tokens through a KTT token deposit with an
 *      applied discount.
 *
 * @author byterocket
 */
contract DiscountZapper is TSOwnable {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when an asset's discount changed.
    /// @param asset The asset's address.
    /// @param oldDiscount The asset's old discount in bps.
    /// @param newDiscount The asset's new discount in bps.
    event DiscountUpdated(
        address indexed asset,
        uint oldDiscount,
        uint newDiscount
    );

    //--------------------------------------------------------------------------
    // Constants

    /// @dev 10,000 bps are 100%.
    uint private constant BPS = 10_000;

    // @todo Issue #18 "What should be the maximum discount allowed?"
    // Need a decision about the value of the following constant.
    // Note that this issue is also open in the Reserve.

    /// @dev The max discount allowed is 30%.
    uint private constant MAX_DISCOUNT = 3_000;

    //--------------------------------------------------------------------------
    // Storage

    /// @dev The treasury implementation address.
    /// @dev Used to bond user assets in order to receive KTT tokens.
    ITreasury private immutable _treasury;

    /// @dev The reserve implementation address.
    /// @dev Used to deposit KTT tokens in order to receive KOL tokens.
    /// @dev The reserve exposes an "Zapper-only" function. The reserve applies
    ///      the Zapper's discount to the deposit.
    IReserve private immutable _reserve;

    /// @notice Returns the discount, denominated in bps, for given asset
    ///         address.
    /// @dev Changeable by owner.
    mapping(address => uint) public discountPerAsset;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(address treasury_, address reserve_) {
        require(treasury_ != address(0));
        require(reserve_ != address(0));

        _treasury = ITreasury(treasury_);
        _reserve = IReserve(reserve_);

        // Give inifinite approval of KTT tokens to the reserve.
        // Note that the KTT token interprets type(uint).max as infinite.
        // Note that the treasury contract is the KTT token contract.
        ERC20(treasury_).approve(reserve_, type(uint).max);
    }

    //--------------------------------------------------------------------------
    // User Mutating Functions

    /// @notice Zap function to deposit assets and receive KOL tokens.
    /// @dev Applies the asset's discount for the deposit, if any.
    /// @param asset The asset's address.
    /// @param amount The amount of assets to deposit.
    /// @return True if successful.
    function zap(address asset, uint amount) external returns (bool) {
        // Note that it's not neccessary to check the asset's code size.
        // This is due to the asset has to be supported by the treasury
        // which includes this check.

        // Fetch assets from msg.sender.
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Give allowance for treasury to spend the asset.
        ERC20(asset).safeApprove(address(_treasury), amount);

        // Bond assets into treasury and receive KTT tokens.
        _treasury.bond(asset, amount);

        // Deposit whole KTT token balance with set discount into reserve.
        // Note that any KTT tokens send accidently to this contract are
        // therefore attributed to the next user calling this function.
        _reserve.depositAllWithDiscountFor(msg.sender, discountPerAsset[asset]);

        return true;
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    /// @notice Sets the discount for a given asset.
    /// @dev Denomination is in bps.
    /// @dev Only callable by owner.
    function setDiscountForAsset(address asset, uint discount)
        external
        onlyOwner
    {
        // Fail if treasury does not support the asset for bonding operations.
        require(_treasury.isSupportedForBonding(asset));

        // Fail if discount is higher than MAX_DISCOUNT constant.
        require(discount <= MAX_DISCOUNT);

        // Update discount for asset and emit event.
        emit DiscountUpdated(asset, discountPerAsset[asset], discount);
        discountPerAsset[asset] = discount;
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @notice Returns the treasury address.
    function treasury() external view returns (address) {
        return address(_treasury);
    }

    /// @notice Returns the reserve address.
    function reserve() external view returns (address) {
        return address(_reserve);
    }

}
