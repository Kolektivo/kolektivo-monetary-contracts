// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "solrocket/Ownable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

import {Treasury} from "./Treasury.sol";
import {KOL} from "./KOL.sol";

interface IOracle {
    // Note that the price is expected to be in 18 decimal precision.
    function getData() external returns (uint, bool);
}

contract Reserve is Ownable, Whitelisted {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Supply can not be increased due to exceeding the reserve limit.
    /// @param backingInBPS The backing of supply in bps.
    /// @param minBackingInBPS The min amount of backing allowed, in bps.
    error SupplyExceedsReserveLimit(uint backingInBPS, uint minBackingInBPS);

    /// @notice Functionality is limited due to stale price delivered by oracle.
    /// @param asset The address of the asset.
    /// @param oracle The address of the asset's oracle.
    error StalePriceDeliveredByOracle(address asset, address oracle);

    //--------------------------------------------------------------------------
    // Events

    event BackingInBPSChanged(uint oldBackingInBPS, uint newBackingInBPS);

    //----------------------------------
    // Owner Events

    /// @notice Event emitted when an asset's oracle is updated.
    /// @param asset The address of the asset.
    /// @param oldOracle The address of the asset's old oracle.
    /// @param newOracle The address of the asset's new oracle.
    event AssetOracleUpdated(address indexed asset,
                             address indexed oldOracle,
                             address indexed newOracle);

    event PriceFloorChanged(uint oldPriceFloor, uint newPriceFloor);

    event PriceCeilingChanged(uint oldPriceCeiling, uint newPriceCeiling);

    event MinBackingInBPSChanged(uint oldMinBackingInBPS,
                                 uint newMinBackingInBPS);

    event IncurredDebt(address indexed who, uint ktts);

    event PayedDebt(address indexed who, uint ktts);

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to enforce the reserve backing is updated after the
    ///      function's execution.
    modifier postambleUpdateBacking() {
        _;

        _updateBackingInBPS();
    }

    /// @dev Modifier to enforce the reserve backing is updated and the min
    ///      backing requirement is satisfied after the function's execution.
    modifier postambleUpdateBackingAndRequireMinBacking() {
        _;

        _updateBackingInBPS();

        // Fail if supply exceeds reserve's backing limit.
        if (_backingInBPS < minBackingInBPS) {
            revert SupplyExceedsReserveLimit(
                _backingInBPS,
                minBackingInBPS
            );
        }
    }

    //--------------------------------------------------------------------------
    // Constants

    /// @dev 10,000 bps are 100%.
    uint private constant BPS = 10_000;

    /// @dev The min amount in bps of reserve to supply.
    uint private constant MIN_BACKING_IN_BPS = 5_000; // 50%

    //--------------------------------------------------------------------------
    // Storage

    /// @dev The KOL token implementation.
    KOL private immutable _kol;

    /// @dev The KTT token implementation.
    ERC20 private immutable _ktt;

    /// @dev The cUSD token implementation.
    ERC20 private immutable _cusd;

    /// @dev The bps of supply backed by the reserve.
    uint private _backingInBPS;

    /// @notice The min amount in bps of reserve to supply.
    /// @dev Changeable by owner.
    uint public minBackingInBPS;

    /// @notice The anticipated price ceiling for KOL.
    /// @dev Denominated in USD with 18 decimal precision.
    /// @dev Changeable by owner.
    uint public priceCeiling;

    /// @notice The anticipated price floor for KOL.
    /// @dev Denominated in USD with 18 decimal precision.
    /// @dev Changeable by owner.
    uint public priceFloor;

    /// @notice The KOL price oracle.
    /// @dev Denominated in USD with 18 decimal precision.
    /// @dev Of type IOracle.
    /// @dev Changeable by owner.
    address public kolPriceOracle;

    /// @notice The cUSD price oracle.
    /// @dev Denominated in USD with 18 decimal precision.
    /// @dev Of type IOracle.
    /// @dev Changeable by owner.
    address public cusdPriceOracle;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(
        address kol_,
        address ktt_,
        address cusd_,
        uint minBackingInBPS_,
        address kolPriceOracle_,
        address cusdPriceOracle_
    ) {
        require(kol_ != address(0));
        require(ktt_ != address(0));
        require(cusd_ != address(0));
        require(minBackingInBPS_ >= MIN_BACKING_IN_BPS);

        // Fail if oracles do not deliver valid data.
        bool valid;
        (/*price*/, valid) = _queryOracle(kolPriceOracle_);
        require(valid);
        (/*price*/, valid) = _queryOracle(cusdPriceOracle_);
        require(valid);

        // Set storage.
        _kol = KOL(kol_);
        _ktt = ERC20(ktt_);
        _cusd = ERC20(cusd_);
        minBackingInBPS = minBackingInBPS_;
        kolPriceOracle = kolPriceOracle_;
        cusdPriceOracle = cusdPriceOracle_;

        // Set current backing to 100%.
        _backingInBPS = BPS;
    }

    //--------------------------------------------------------------------------
    // User Mutating Functions

    /// @notice Deposits KTT tokens from msg.sender and mints corresponding KOL
    ///         tokens to msg.sender.
    /// @param ktts The amount of KTT tokens to deposit.
    function deposit(uint ktts) external onlyWhitelisted {
        _deposit(msg.sender, msg.sender, ktts);
    }

    /// @notice Deposits KTT tokens from msg.sender and mints corresponding KOL
    ///         tokens to some address.
    /// @param to The address to mint KOL tokens to.
    /// @param ktts The amount of KTT tokens to deposit.
    function depositFor(address to, uint ktts) external onlyWhitelisted {
        _deposit(msg.sender, to, ktts);
    }

    /// @notice Deposits all KTT tokens from msg.sender and mints corresponding
    ///         KOL tokens to msg.sender.
    function depositAll() external onlyWhitelisted {
        uint ktts = _ktt.balanceOf(msg.sender);

        _deposit(msg.sender, msg.sender, ktts);
    }

    /// @notice Deposits all KTT tokens from msg.sender and mints corresponding
    ///         KOL tokens to some address.
    /// @param to The address to mint KOL tokens to.
    function depositAllFor(address to) external onlyWhitelisted {
        uint ktts = _ktt.balanceOf(msg.sender);

        _deposit(msg.sender, to, ktts);
    }

    /// @notice Burns some KOL tokens from msg.sender and withdraws
    ///         corresponding KTT tokens to msg.sender.
    /// @param kols The amount of KOL tokens to burn.
    function withdraw(uint kols) external onlyWhitelisted {
        _withdraw(msg.sender, msg.sender, kols);
    }

    /// @notice Burns some KOL tokens from msg.sender and withdraws
    ///         corresponding KTT tokens to some address.
    /// @param to The address to withdraw KTT tokens to.
    /// @param kols The amount of KOL tokens to burn.
    function withdrawFor(address to, uint kols) external onlyWhitelisted {
        return _withdraw(msg.sender, to, kols);
    }

    /// @notice Burns all KOL tokens from msg.sender and withdraws
    ///         corresponding KTT tokens to msg.sender.
    function withdrawAll() external onlyWhitelisted {
        uint kols = _kol.balanceOf(msg.sender);

        _withdraw(msg.sender, msg.sender, kols);
    }

    /// @notice Burns all KOL tokens from msg.sender and withdraws
    ///         corresponding KTT tokens to some address.
    /// @param to The address to withdraw KTT tokens to.
    function withdrawAllFor(address to) external onlyWhitelisted {
        uint kols = _kol.balanceOf(msg.sender);

        _withdraw(msg.sender, to, kols);
    }

    function swapExactCUSDForKOL(uint amount) external onlyWhitelisted {
        revert("NOT YET IMPLEMENTED");
    }

    function swapExactKOLForCUSD(uint amount) external onlyWhitelisted {
        revert("NOT YET IMPLEMENTED");
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Oracle Management

    /// @notice Sets the cUSD price oracle address.
    /// @dev Only callable by owner.
    function setCUSDPriceOracle(address oracle) external onlyOwner {
        // Return early if state does not change.
        if (cusdPriceOracle == oracle) {
            return;
        }

        // Fail if oracle does not deliver valid data.
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert StalePriceDeliveredByOracle(address(_cusd), oracle);
        }

        // Update oracle and emit event.
        emit AssetOracleUpdated(address(_cusd), cusdPriceOracle, oracle);
        cusdPriceOracle = oracle;
    }

    /// @notice Sets the KOL price oracle address.
    /// @dev Only callable by owner.
    function setKOLPriceOracle(address oracle) external onlyOwner {
        // Return early if state does not change.
        if (kolPriceOracle == oracle) {
            return;
        }

        // Fail if oracle does not deliver valid data.
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert StalePriceDeliveredByOracle(address(this), oracle);
        }

        // Update oracle and emit event.
        emit AssetOracleUpdated(address(this), kolPriceOracle, oracle);
        kolPriceOracle = oracle;
    }

    //----------------------------------
    // Price Floor/Ceiling Management

    /// @notice Sets the KOL tokens anticipated price floor.
    /// @dev Only callable by owner.
    function setPriceFloor(uint priceFloor_) external onlyOwner {
        require(priceFloor_ <= priceCeiling && priceFloor_ != 0);

        // Return early if state does not change.
        if (priceFloor == priceFloor_) {
            return;
        }

        emit PriceFloorChanged(priceFloor, priceFloor_);
        priceFloor = priceFloor_;
    }

    /// @notice Sets the KOL tokens anticipated price ceiling.
    /// @dev Only callable by owner.
    function setPriceCeiling(uint priceCeiling_) external onlyOwner {
        require(priceCeiling_ >= priceFloor && priceCeiling_ != 0);

        // Return early if state does not change.
        if (priceCeiling == priceCeiling_) {
            return;
        }

        emit PriceCeilingChanged(priceCeiling, priceCeiling_);
        priceCeiling = priceCeiling_;
    }

    //----------------------------------
    // Debt Management

    /// @notice Sets the minimum backing requirement for the reserve.
    /// @dev Denomination is in bps.
    /// @dev Only callable by owner.
    function setMinBackingInBPS(uint minBackingInBPS_) external onlyOwner {
        require(minBackingInBPS_ >= MIN_BACKING_IN_BPS);

        // Return early if state does not change.
        if (minBackingInBPS == minBackingInBPS_) {
            return;
        }

        emit MinBackingInBPSChanged(minBackingInBPS, minBackingInBPS_);
        minBackingInBPS = minBackingInBPS_;
    }

    /// @notice Incurs an amount of debt by minting KOL tokens to msg.sender.
    /// @dev Denomination is in KTT tokens.
    /// @dev Enforces that reserve backing is not lower than min backing.
    /// @dev Only callable by owner.
    function incurDebt(uint ktts)
        external
        postambleUpdateBackingAndRequireMinBacking
        onlyOwner
    {
        // Note to not create debt without any reserve backing.
        require(_reserveAdjusted() != 0);

        // @todo Emit event, adjust tests.

        // Note that the conversion rate of KOL:KTT is 1:1.
        _kol.mint(msg.sender, ktts);
    }

    /// @notice Pays an amount of debt by burning KOL tokens from msg.sender.
    /// @dev Denomination is in KOL tokens.
    /// @dev Only callable by owner.
    function payDebt(uint kols)
        external
        // Note that min backing is not enforced. Otherwise it would be
        // impossible to partially pay back debt after KTT supply contracted
        // to below min backing requirement.
        postambleUpdateBacking
        onlyOwner
    {
        _kol.burn(msg.sender, kols);

        // @todo Emit event, adjust tests.
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

    /// @notice Returns the KOL token address.
    function kol() external view returns (address) {
        return address(_kol);
    }

    /// @notice Returns the KTT token address, i.e. the token the reserve is
    ///         composed off.
    function ktt() external view returns (address) {
        return address(_ktt);
    }

    /// @notice Returns the cUSD token address.
    function cusd() external view returns (address) {
        return address(_cusd);
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

    /// @dev Handles user deposits.
    function _deposit(address from, address to, uint ktts)
        private
        postambleUpdateBacking
    {
        _ktt.safeTransferFrom(from, address(this), ktts);

        // Note that the conversion rate of KOL:KTT is 1:1.
        _kol.mint(to, ktts);
    }

    /// @dev Handles user withdrawals.
    function _withdraw(address from, address to, uint kols)
        private
        postambleUpdateBacking
    {
        // Note that the conversion rate of KOL:KTT is 1:1.
        _ktt.safeTransfer(to, kols);

        _kol.burn(from, kols);
    }

    /// @dev Updates the bps of supply that is backed by the reserve.
    /// @dev Not NOT be called directly but rather used through the
    ///      postambleUpdateBacking* modifiers.
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
        // Note that KTT is in 18 decimal precision and is assumed to always
        // have an intrinsic value of 1 USD.
        return _ktt.balanceOf(address(this));
    }

    /// @dev Returns the current supply in USD denomination with 18 decimal
    ///      precision.
    function _supply() private view returns (uint) {
        return _kol.totalSupply();
    }

    /// @dev Querys an address of type IOracle.
    function _queryOracle(address oracle) private returns (uint, bool) {
        uint data;
        bool valid;
        (data, valid) = IOracle(oracle).getData();

        return (data, valid);
    }

}
