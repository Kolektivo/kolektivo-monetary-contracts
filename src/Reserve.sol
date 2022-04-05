// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "solrocket/Ownable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

import {Treasury} from "./Treasury.sol";
import {KOL} from "./KOL.sol";

interface IOracle {
    // Note that the price is returned with 18 decimal precision.
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

    /// @notice Event emitted when an asset's oracle is updated.
    /// @param asset The address of the asset.
    /// @param oldOracle The address of the asset's old oracle.
    /// @param newOracle The address of the asset's new oracle.
    event AssetOracleUpdated(address indexed asset,
                             address indexed oldOracle,
                             address indexed newOracle);

    //--------------------------------------------------------------------------
    // Events

    event BackingInBPSChanged(uint oldBackingInBPS, uint newBackingInBPS);

    //----------------------------------
    // Owner Events

    event PriceFloorChanged(uint oldPriceFloor, uint newPriceFloor);

    event PriceCeilingChanged(uint oldPriceCeiling, uint newPriceCeiling);

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

    /// @dev Note that KTT and KOL use the same decimal precision.
    uint private constant KTT_DECIMALS = 18;
    uint private constant KOL_DECIMALS = 18;

    //--------------------------------------------------------------------------
    // Storage

    /// @dev The KOL token implementation.
    KOL private immutable _kol;

    /// @dev The KTT token implementation.
    ERC20 private immutable _ktt;

    /// @dev The cUSD token implementation.
    ERC20 private immutable _cUSD;

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

    /// @notice The cUSD price oracle.
    /// @dev Denominated in USD with 18 decimal precision.
    /// @dev Of type IOracle.
    /// @dev Changeable by owner.
    address public oracleCUSD;

    /// @notice The KOL price oracle.
    /// @dev Denominated in USD with 18 decimal precision.
    /// @dev Of type IOracle.
    /// @dev Changeable by owner.
    address public oracleKOL;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(
        address kol_,
        address ktt_,
        address cUSD_,
        uint minBackingInBPS_,
        address oracleKOL_,
        address oracleCUSD_
    ) {
        require(kol_ != address(0));
        require(ktt_ != address(0));
        require(cUSD_ != address(0));
        require(minBackingInBPS_ >= MIN_BACKING_IN_BPS);

        // Fail if oracles do not deliver valid data.
        bool valid;
        (/*price*/, valid) = _queryOracle(oracleKOL_);
        require(valid);
        (/*price*/, valid) = _queryOracle(oracleCUSD_);
        require(valid);

        // Set storage.
        _kol = KOL(kol_);
        _ktt = ERC20(ktt_);
        _cUSD = ERC20(cUSD_);
        minBackingInBPS = minBackingInBPS_;
        oracleKOL = oracleKOL_;
        oracleCUSD = oracleCUSD_;

        // Set current backing to 100%.
        _backingInBPS = BPS;
    }

    //--------------------------------------------------------------------------
    // User Mutating Functions

    // @todo depositAll, depositAllFor etc. (ButtonWrapper).

    /// @notice Deposits KTT tokens from msg.sender and mints corresponding KOL
    ///         tokens to msg.sender.
    /// @param ktts The amount of KTT tokens to deposit.
    function deposit(uint ktts) external onlyWhitelisted {
        _ktt.safeTransferFrom(msg.sender, address(this), ktts);

        // Note that the conversion rate of KOL:KTT is 1:1.
        _kol.mint(msg.sender, ktts);

        // @todo Not strictly necessary. But why not use the chance?
        //       Or better create backend task to call function regularly?
        _updateBackingInBPS();

        emit Deposit(msg.sender, ktts);
    }

    /// @notice Withdraws KTT tokens to msg.sender and burns KOL tokens from
    ///         msg.sender.
    /// @param kols The amount of KOL tokens to burn.
    function withdraw(uint kols) external onlyWhitelisted {
        // Note that the conversion rate of KOL:KTT is 1:1.
        _ktt.safeTransfer(msg.sender, kols);

        _kol.burn(msg.sender, kols);

        // @todo See function deposit.
        _updateBackingInBPS();

        emit Withdrawal(msg.sender, kols);
    }

    function swapExactCUSDForKOL(uint amount) external onlyWhitelisted {

    }

    function swapExactKOLForCUSD(uint amount) external onlyWhitelisted {

    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Oracle Management

    function setCUSDPriceOracle(address oracle) external onlyOwner {
        // Return early if state does not change.
        if (oracleCUSD == oracle) {
            return;
        }

        // Fail if oracle does not deliver valid data.
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert StalePriceDeliveredByOracle(address(_cUSD), oracle);
        }

        // Update oracle and emit event.
        emit AssetOracleUpdated(address(_cUSD), oracleCUSD, oracle);
        oracleCUSD = oracle;
    }

    function setKOLPriceOracle(address oracle) external onlyOwner {
        // Return early if state does not change.
        if (oracleKOL == oracle) {
            return;
        }

        // Fail if oracle does not deliver valid data.
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert StalePriceDeliveredByOracle(address(_kol), oracle);
        }

        // Update oracle and emit event.
        emit AssetOracleUpdated(address(_kol), oracleKOL, oracle);
        oracleKOL = oracle;
    }

    //----------------------------------
    // Price Floor/Ceiling Management

    function setPriceFloor(uint priceFloor_) external onlyOwner {
        require(priceFloor_ <= priceCeiling && priceFloor_ != 0);

        // Return early if state does not change.
        if (priceFloor == priceFloor_) {
            return;
        }

        emit PriceFloorChanged(priceFloor, priceFloor_);
        priceFloor = priceFloor_;
    }

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

    function setMinBackingInBPS(uint minBackingInBPS_) external onlyOwner {
        require(minBackingInBPS_ >= MIN_BACKING_IN_BPS);

        // Return early if state does not change.
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

        // Note that the conversion rate of KOL:KTT is 1:1.
        _kol.mint(msg.sender, ktts);

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
        // Note that KTT is in 18 decimal precision and is assumed to always
        // have an intrinsic value of 1 USD.
        return _ktt.balanceOf(address(this));
    }

    /// @dev Returns the current supply in USD denomination with 18 decimal
    ///      precision.
    function _supply() private view returns (uint) {
        return _kol.totalSupply();
    }

    function _queryOracle(address oracle) private returns (uint, bool) {
        uint data;
        bool valid;
        (data, valid) = IOracle(oracle).getData();

        return (data, valid);
    }

}
