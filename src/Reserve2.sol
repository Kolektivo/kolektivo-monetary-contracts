// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {IERC20} from "./interfaces/_external/IERC20.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {TSOwnable} from "solrocket/TSOwnable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

import {Treasury} from "./Treasury.sol";

import {IOracle} from "./interfaces/IOracle.sol";
import {IVestingVault} from "./interfaces/IVestingVault.sol";
import {IReserve2} from "./interfaces/IReserve2.sol";

import {Wad} from "./lib/Wad.sol";

/**
 Notes:
    - supported means asset has an oracle and is being taking into account
      for the backing calculation.
    - KTT is no special token anymore. We make oracle for KTT and treat it as normal ERC20.
        - ok
    - max un/bonding not implemented. I think it's better to observe and disable per backend.
        - insgesamt XXX erc20 amount darf gebonded werden.
    - For backing calculation: Should we have oracle for KOL/token? Or assume 1$? O.o
        - mit oracle fuer KOL
 */

// @todo Check for grammar tool in VSCode.

/**
 TODOs:
    -
 */

interface IERC20MintBurn is IERC20 {
    function mint(address to, uint amount) external;
    function burn(address from, uint amount) external;
}

/**
 * @title Reserve2
 *
 * @dev ...
 *
 * @author byterocket
 */
contract Reserve2 is TSOwnable, IReserve2 {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Modifiers

    modifier validRecipient(address to) {
        if (to == address(0) || to == address(this)) {
            revert("Invalid recipient");
        }
        _;
    }

    modifier validAmount(uint amount) {
        if (amount == 0) {
            revert("Invalid amount");
        }
        _;
    }

    modifier isSupportedERC20(address erc20) {
        if (oraclePerERC20[erc20] == address(0)) {
            revert("ERC20 not supported");
        }
        _;
    }

    modifier isSupportedERC721Id(ERC721Id memory erc721) {
        if (oraclePerERC721Id[_hashOfERC721Id(erc721)] == address(0)) {
            revert("ERC721Id not supported");
        }
        _;
    }

    modifier isBondableERC20(address erc20) {
        if (!isERC20Bondable[erc20]) {
            revert("ERC20 not bondable");
        }
        _;
    }

    modifier isBondableERC721Id(ERC721Id memory erc721Id) {
        if (!isERC721IdBondable[_hashOfERC721Id(erc721Id)]) {
            revert("ERC721Id not bondable");
        }
        _;
    }

    modifier isUnbondableERC20(address erc20) {
        if (!isERC20Unbondable[erc20]) {
            revert("ERC20 not unbondable");
        }
        _;
    }

    modifier isUnbondableERC721Id(ERC721Id memory erc721Id) {
        if (!isERC721IdUnbondable[_hashOfERC721Id(erc721Id)]) {
            revert("ERC721Id not unbondable");
        }
        _;
    }

    modifier isNotExceedingERC20BondingLimit(address erc20, uint amount) {
        uint balance = ERC20(erc20).balanceOf(address(this));
        uint limit = bondingLimitPerERC20[erc20];

        // Note that a limit of zero is interpreted as limit given.
        if (limit != 0 && balance + amount > limit) {
            revert("ERC20 bond limit reached");
        }

        _;
    }

    modifier onBeforeUpdateBacking(bool requireMinBacking) {
        _;

        _updateBacking();

        if (requireMinBacking && _backing < minBacking) {
            revert("backin < minBacking");
        }
    }

    //--------------------------------------------------------------------------
    // Constants and Immutables

    /// @dev 10,000 bps are 100%.
    uint private constant BPS = 10_000;

    /// @dev Needs to have 18 decimal precision.
    IERC20MintBurn private immutable _token;
    // @todo Should not be immutable.
    address private immutable _tokenOracle;

    // @todo Should not be immutable.
    IVestingVault private immutable _vestingVault;

    //--------------------------------------------------------------------------
    // Storage

    //----------------------------------
    // Supported Assets Mappings

    address[] public supportedERC20s;
    ERC721Id[] public supportedERC721Ids;

    //----------------------------------
    // Oracle Mappings

    // address of type ERC20 => address of type IOracle.
    mapping(address => address) public oraclePerERC20;
    // ERC721Id => address of type IOracle.
    mapping(bytes32 => address) public oraclePerERC721Id;

    //----------------------------------
    // Un/Bondable Mappings

    mapping(address => bool) public isERC20Bondable;
    mapping(address => bool) public isERC20Unbondable;

    mapping(bytes32 => bool) public isERC721IdBondable;
    mapping(bytes32 => bool) public isERC721IdUnbondable;

    //----------------------------------
    // Discount Mappings

    mapping(address => uint) public discountPerERC20;
    mapping(bytes32 => uint) public discountPerERC721Id;

    //----------------------------------
    // Vesting Mappings

    mapping(address => uint) public vestingDurationPerERC20;
    mapping(bytes32 => uint) public vestingDurationPerERC721Id;

    //----------------------------------
    // Bonding Limit Mappings

    /// @dev If limit is 0 it's treated as infinte, i.e. no maximum set.
    mapping(address => uint) public bondingLimitPerERC20;

    // @todo onlyOwner setter functions.
    mapping(address => uint) public unbondingLimitPerERC20;

    //----------------------------------
    // Reserve Management

    uint private _backing;
    uint public minBacking;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(
        address token_,
        address tokenOracle_,
        address vestingVault_,
        uint minBacking_
    ) {
        // Check token's validity.
        require(token_ != address(0));
        require(token_.code.length != 0);

        // Check that tokenOracle delivers valid data.
        /*uint price = */ _queryOracle(tokenOracle_);

        // Check vestingVault's validity.
        require(vestingVault_ != address(0));
        require(IVestingVault(vestingVault_).token() == token_);

        // Set storage.
        _token = IERC20MintBurn(token_);
        _tokenOracle = tokenOracle_;
        _vestingVault = IVestingVault(vestingVault_);
        minBacking = minBacking_;

        // Set current backing to 100%;
        _backing = BPS;
    }

    //--------------------------------------------------------------------------
    // User Mutating Functions

    //----------------------------------
    // Bond Functions

    //--------------
    // Bond ERC20 Functions

    // @todo Changed function param order of un/bond functions!

    function bondERC20(address erc20, uint erc20Amount) external {
        _bondERC20(erc20, msg.sender, msg.sender, erc20Amount);
    }

    function bondERC20For(
        address erc20,
        address to,
        uint erc20Amount
    ) external {
        _bondERC20(erc20, msg.sender, to, erc20Amount);
    }

    function bondERC20All(address erc20) external {
        _bondERC20(
            erc20,
            msg.sender,
            msg.sender,
            ERC20(erc20).balanceOf(msg.sender)
        );
    }

    function bondERC20AllFor(address erc20, address to) external {
        _bondERC20(
            erc20,
            msg.sender,
            to,
            ERC20(erc20).balanceOf(msg.sender)
        );
    }

    //--------------
    // Bond ERC721Id Functions

    function bondERC721Id(ERC721Id memory erc721Id) external {
        _bondERC721Id(erc721Id, msg.sender, msg.sender);
    }

    function bondERC721IdFor(ERC721Id memory erc721Id, address to) external {
        _bondERC721Id(erc721Id, msg.sender, to);
    }

    //----------------------------------
    // Unbond Functions

    //--------------
    // Unbond ERC20 Functions

    function unbondERC20(address erc20, uint tokenAmount) external {
        _unbondERC20(erc20, msg.sender, msg.sender, tokenAmount);
    }

    function unbondERC20To(
        address erc20,
        address to,
        uint tokenAmount
    ) external {
        _unbondERC20(erc20, msg.sender, to, tokenAmount);
    }

    function unbondERC20All(address erc20) external {
        _unbondERC20(
            erc20,
            msg.sender,
            msg.sender,
            _token.balanceOf(address(this))
        );
    }

    function unbondERC20AllTo(address erc20, address to) external {
        _unbondERC20(
            erc20,
            msg.sender,
            to,
            _token.balanceOf(address(this))
        );
    }

    //--------------
    // Unbond ERC721Id Functions

    function unbondERC721Id(
        ERC721Id memory erc721Id,
        uint tokenAmount
    ) external {
        _unbondERC721Id(erc721Id, msg.sender, msg.sender, tokenAmount);
    }

    function unbondERC721IdTo(
        ERC721Id memory erc721Id,
        address to,
        uint tokenAmount
    ) external {
        _unbondERC721Id(erc721Id, msg.sender, to, tokenAmount);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Emergency Functions
    // For more info see Issue #2.

    /// @notice Executes a call on a target.
    /// @dev Only callable by owner.
    /// @param target The address to call.
    /// @param callData The call data.
    function executeTx(address target, bytes memory callData)
        external
        onlyOwner
    {
        bool success;
        (success, /*returnData*/) = target.call(callData);
        require(success);
    }

    //----------------------------------
    // Asset and Oracle Management

    function supportERC20(address erc20, address oracle) external onlyOwner {
        // Make sure that erc20's code is non-empty.
        // Note that solmate's SafeTransferLib does not include this check.
        require(erc20.code.length != 0);

        address oldOracle = oraclePerERC20[erc20];

        // Do nothing if erc20 is already supported and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert is erc20 is already supported but oracles differ.
        // Note that the updateOracleForERC20 function should be used for this.
        require(oldOracle == address(0));

        // Check that oracle delivers valid data.
        /*uint price = */ _queryOracle(oracle);

        // Add erc20 and oracle to mappings.
        supportedERC20s.push(erc20);
        oraclePerERC20[erc20] = oracle;

        // Notify off-chain services.
        // @todo emit event.
    }

    function supportERC721Id(ERC721Id memory erc721Id, address oracle)
        external
        onlyOwner
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Make sure that erc721Id's code is non-empty.
        // @todo Does solmate check this?
        require(erc721Id.erc721.code.length != 0);

        address oldOracle = oraclePerERC721Id[erc721IdHash];

        // Do nothing if erc721Id is already supported and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert if erc721Id is already supported but oracles differ.
        // Note that the updateOracleForERC721Id function should be used for this.
        require(oldOracle == address(0));

        // Check that oracle delivers valid data.
        /*uint price = */ _queryOracle(oracle);

        // Add erc721Id and oracle to mappings.
        supportedERC721Ids.push(erc721Id);
        oraclePerERC721Id[erc721IdHash] = oracle;

        // Notify off-chain services.
        // @todo Emit event.
    }

    function unsupportERC20(address erc20) external onlyOwner {
        // Do nothing if erc20 is already not supported.
        // Note that we do not use the isSupportedERC20 modifier to be idempotent.
        if (oraclePerERC20[erc20] == address(0)) {
            return;
        }

        // Remove erc20's oracle.
        delete oraclePerERC20[erc20];

        // Remove erc20 from the supportedERC20s array.
        uint len = supportedERC20s.length;
        for (uint i; i < len; ) {
            if (erc20 == supportedERC20s[i]) {
                // It not last elem in array, copy last elem to this index.
                if (i < len - 1) {
                    supportedERC20s[i] = supportedERC20s[len - 1];
                }
                supportedERC20s.pop();

                // @todo Emit event.
                break;
            }

            unchecked { ++i; }
        }
    }

    function unsupportERC721Id(ERC721Id memory erc721Id) external onlyOwner {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Do nothing if erc721 is already not supported.
        // Note that we do not use the isSupportedERC721Id modifier to be idempotent.
        if (oraclePerERC721Id[erc721IdHash] == address(0)) {
            return;
        }

        // Remove erc721Id's oracle.
        delete oraclePerERC721Id[erc721IdHash];

        // Remove erc721Id from the supportedERC721Ids array.
        uint len = supportedERC721Ids.length;
        for (uint i; i < len; ) {
            if (erc721IdHash == _hashOfERC721Id(supportedERC721Ids[i])) {
                // It not last elem in array, copy last elem to this index.
                if (i < len - 1) {
                    supportedERC721Ids[i] = supportedERC721Ids[len - 1];
                }
                supportedERC721Ids.pop();

                // @todo Emit event.
                break;
            }

            unchecked { ++i; }
        }
    }

    function updateOracleForERC20(address erc20, address oracle)
        external
        isSupportedERC20(erc20)
        onlyOwner
    {
        // Cache old oracle.
        address oldOracle = oraclePerERC20[erc20];

        // Do nothing if new oracle is same as old oracle.
        if (oldOracle == oracle) {
            return;
        }

        // Check that new oracle delivers valid data.
        /*uint price = */ _queryOracle(oracle);

        // Update erc20's oracle and notify off-chain services.
        oraclePerERC20[erc20] = oracle;
        // @todo Emit event.
    }

    function updateOracleForERC721Id(ERC721Id memory erc721Id, address oracle)
        external
        isSupportedERC721Id(erc721Id)
        onlyOwner
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Cache old oracle.
        address oldOracle = oraclePerERC721Id[erc721IdHash];

        // Do nothing if new oracle is same as old oracle.
        if (oldOracle == oracle) {
            return;
        }

        // Check that new oracle delivers valid data.
        /*uint price = */ _queryOracle(oracle);

        // Update erc721Id's oracle and notify off-chain services.
        oraclePerERC721Id[erc721IdHash] = oracle;
        // @todo Emit event.
    }

    //----------------------------------
    // Discount Management

    function setDiscountForERC20(address erc20, uint discount)
        external
        isSupportedERC20(erc20)
        onlyOwner
    {
        // Cache old discount.
        uint oldDiscount = discountPerERC20[erc20];

        if (discount != oldDiscount) {
            discountPerERC20[erc20] = discount;
            // @todo Emit event.
        }
    }

    function setDiscountForERC721Id(ERC721Id memory erc721Id, uint discount)
        external
        isSupportedERC721Id(erc721Id)
        onlyOwner
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Cache old discount.
        uint oldDiscount = discountPerERC721Id[erc721IdHash];

        if (discount != oldDiscount) {
            discountPerERC721Id[erc721IdHash] = discount;
            // @todo Emit event.
        }
    }

    //----------------------------------
    // Vesting Management

    function setVestingForERC20(address erc20, uint vesting)
        external
        isSupportedERC20(erc20)
        onlyOwner
    {
        // Cache old vesting.
        uint oldVesting = vestingDurationPerERC20[erc20];

        if (vesting != oldVesting) {
            vestingDurationPerERC20[erc20] = vesting;
            // @todo Emit event.
        }
    }

    function setVestingForERC721Id(ERC721Id memory erc721Id, uint vesting)
        external
        isSupportedERC721Id(erc721Id)
        onlyOwner
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Cache old vesting.
        uint oldVesting = vestingDurationPerERC721Id[erc721IdHash];

        if (vesting != oldVesting) {
            vestingDurationPerERC721Id[erc721IdHash] = vesting;
            // @todo Emit event.
        }
    }

    //----------------------------------
    // Reserve Management

    function setMinBacking(uint minBacking_) external onlyOwner {
        if (minBacking != minBacking_) {
            // @todo Emit event.
            minBacking = minBacking_;
        }
    }

    function incurDebt(uint amount)
        external
        onBeforeUpdateBacking(true)
        onlyOwner
    {
        // Mint tokens, i.e. create debt.
        _token.mint(msg.sender, amount);

        // Notify off-chain services.
        // @todo Emit event.
    }

    function payDebt(uint amount)
        external
        // Note that min backing is not enforced. Otherwise it would be
        // impossible to partially repay debt after valuation contracted to
        // below min backing requirement.
        onBeforeUpdateBacking(false)
        onlyOwner
    {
        // Burn tokens, i.e. repay debt.
        _token.burn(msg.sender, amount);

        // Notify off-chain services.
        // @todo Emit event.
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    function token() external view returns (address) {
        return address(_token);
    }

    // @todo Function can not be view because IOracle.getData() is not view.
    /// @return uint Reserve asset's valuation in USD with 18 decimal precision.
    /// @return uint Token supply's valuation in USD with 18 decimal precision.
    /// @return uint BPS of supply backed by reserve.
    function reserveStatus() external returns (uint, uint, uint) {
        return (_reserveValuation(), _supplyValuation(), _backing);
    }

    //--------------------------------------------------------------------------
    // Private Functions

    //----------------------------------
    // Bond Functions

    function _bondERC20(
        address erc20,
        address from,
        address to,
        uint erc20Amount
    )
        private
        // Note that if an ERC20 is bondable, it is also supported.
        // isSupportedERC20(erc20)
        isBondableERC20(erc20)
        isNotExceedingERC20BondingLimit(erc20, erc20Amount)
        validRecipient(to)
        validAmount(erc20Amount)
        onBeforeUpdateBacking(true)
    {
        // Fetch amount of erc20 tokens.
        ERC20(erc20).safeTransferFrom(from, address(this), erc20Amount);

        uint toMint = _getTokenAmountToMint(erc20, erc20Amount);

        // Mint tokens.
        _commitERC20TokenMint(erc20, to, toMint);
    }

    function _bondERC721Id(
        ERC721Id memory erc721Id,
        address from,
        address to
    )
        private
        // Note that if an ERC721Id is bondable, it is also supported.
        // isSupportedERC721Id(erc721Id)
        isBondableERC721Id(erc721Id)
        validRecipient(to)
        onBeforeUpdateBacking(true)
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Fetch erc721Id.
        ERC721(erc721Id.erc721).safeTransferFrom(
            from,
            address(this),
            erc721Id.id
        );

        // Query erc721Id's price oracle.
        uint priceWad = _queryOracle(oraclePerERC721Id[erc721IdHash]);

        // Note that the price equals the token amount to mint because the
        // amount bonded is always 1 (no discount applied yet).
        uint toMint = priceWad;

        // Query token's price oracle.
        // Note that the priceWad variable is re-used.
        priceWad = _queryOracle(_tokenOracle);

        // Add discount if applicable.
        uint discount = discountPerERC721Id[erc721IdHash];
        if (discount != 0) {
            toMint += (toMint * discount) / BPS;
        }

        // Mint tokens.
        _commitERC721IdTokenMint(erc721IdHash, to, toMint);
    }

    //----------------------------------
    // Unbond Functions

    // @todo Note that unbonding does not have any discount or vesting options.

    function _unbondERC20(
        address erc20,
        address from,
        address to,
        uint tokenAmount
    )
        private
        // Note that if an ERC20 is unbondable, it is also supported.
        // isSupportedERC20(erc20)
        isUnbondableERC20(erc20)
        validRecipient(to)
        validAmount(tokenAmount)
        onBeforeUpdateBacking(true)
    {
        // Query token's price oracle.
        uint priceWad = _queryOracle(_tokenOracle);

        // Calculate valuation of tokens to burn.
        uint tokenValue = (tokenAmount * priceWad) / 1e18;

        // Query erc20's price oracle.
        // Note that the priceWad variable is re-used.
        priceWad = _queryOracle(_tokenOracle);

        // Calculate the amount of erc20 tokens to withdraw.
        uint erc20Amount = (tokenValue * 1e18) / priceWad;

        // Revert in case erc20 tokens are not withdrawable.
        if (!_isERC20AmountWithdrawable(erc20, erc20Amount)) {
            revert("ERC20 unbonding limit exceeded");
        }

        // Withdraw erc20s and burn tokens.
        ERC20(erc20).safeTransfer(to, erc20Amount);
        _token.burn(from, tokenAmount);
    }

    function _unbondERC721Id(
        ERC721Id memory erc721Id,
        address from,
        address to,
        uint tokenAmount
    )
        private
        // Note that if an ERC721Id is unbondable, it is also supported.
        // isSupportedERC721Id(erc721Id)
        isUnbondableERC721Id(erc721Id)
        validRecipient(to)
        validAmount(tokenAmount)
        onBeforeUpdateBacking(true)
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Query token's price oracle.
        uint priceWad = _queryOracle(_tokenOracle);

        // Calculate valuation of tokens to burn.
        uint tokenValue = (tokenAmount * priceWad) / 1e18;

        // Query erc721Id's price oracle.
        // Note that the priceWad variable is re-used.
        priceWad = _queryOracle(oraclePerERC721Id[erc721IdHash]);

        // Revert if valuation of token amount not sufficient.
        if (priceWad > tokenValue) {
            revert("Insufficient Token Amount");
        }

        // Withdraw ERC721Id and burn tokens.
        ERC721(erc721Id.erc721).safeTransferFrom(
            address(this),
            to,
            erc721Id.id
        );
        _token.burn(from, tokenAmount);
    }

    function _isERC20AmountWithdrawable(address erc20, uint amount)
        private
        returns (bool)
    {
        // @todo Check that erc20Amount non-zero.
        uint balance = ERC20(erc20).balanceOf(address(this));
        if (balance < amount) {
            return false;
        }

        uint limit = unbondingLimitPerERC20[erc20];
        if (balance - amount < limit) {
            return false;
        }

        return true;
    }

    function _getTokenAmountToMint(address erc20, uint amount)
        private
        returns (uint)
    {
        // Query erc20's price oracle.
        uint priceWad = _queryOracle(oraclePerERC20[erc20]);

        // Calculate the total value of erc20 tokens.
        uint valuationWad = (amount * priceWad) / 1e18;

        // Calculate the number of tokens to mint (no discount applied yet).
        uint toMint = (valuationWad * _queryOracle(_tokenOracle)) / BPS;

        // Add discount.
        toMint = _applyDiscount(erc20, toMint);

        return toMint;
    }

    //----------------------------------
    // Reserve Functions

    function _updateBacking() private {
        uint reserveValuation = _reserveValuation();
        uint supplyValuation = _supplyValuation();

        // Update backing percentage.
        // Note that denomination is in bps.
        uint newBacking =
            reserveValuation >= supplyValuation
                // Fully backed reserve.
                ? BPS
                // Partially backed reserve.
                : (reserveValuation * BPS) / supplyValuation;

        // Notify off-chain services.
        // @todo Emit event.

        // Update storage.
        _backing = newBacking;
    }

    function _supplyValuation() private returns (uint) {
        // Query token's price.
        uint priceWad = _queryOracle(_tokenOracle);

        // Calculate and return total valuation of tokens created.
        return (_token.totalSupply() * priceWad) / 1e18;
    }

    function _reserveValuation() private returns (uint) {
        return _reserveERC20sValuation() + _reserveERC721IdsValuation();
    }

    function _reserveERC20sValuation() private returns (uint) {
        // The total valuation of ERC20 assets in the reserve.
        uint totalWad;

        // Declare variables outside of loop to save gas.
        address erc20;
        uint balanceWad;
        uint priceWad;
        bool valid;

        // Calculate the total valuation of ERC20 assets in the reserve.
        uint len = supportedERC20s.length;
        for (uint i; i < len; ) {
            erc20 = supportedERC20s[i];

            // Fetch erc20 balance in wad format.
            balanceWad = Wad.convertToWad(
                erc20,
                ERC20(erc20).balanceOf(address(this))
            );

            // Continue/Break if erc20 balance is zero.
            if (balanceWad == 0) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked { ++i; }
                    continue;
                }
            }

            // Query oracle for erc20's price.
            priceWad = _queryOracle(oraclePerERC20[erc20]);

            // Add asset's valuation to the total valuation.
            totalWad += (balanceWad * priceWad) / 1e18;

            unchecked { ++i; }
        }

        return totalWad;
    }

    function _reserveERC721IdsValuation() private returns (uint) {
        // The total valuation of ERC721 assets in the reserve.
        uint totalWad;

        // Declare variables outside of loop to save gas.
        ERC721Id memory erc721Id;
        bytes32 erc721IdHash;
        uint priceWad;
        bool valid;

        uint len = supportedERC721Ids.length;
        for (uint i; i < len; ) {
            erc721Id = supportedERC721Ids[i];
            erc721IdHash = _hashOfERC721Id(erc721Id);

            // Continue/Break if reserve is not the owner of that erc721Id.
            if (ERC721(erc721Id.erc721).ownerOf(erc721Id.id) != address(this)) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked { ++i; }
                    continue;
                }
            }

            // Query oracle for erc721Id's price.
            priceWad = _queryOracle(oraclePerERC721Id[erc721IdHash]);

            // Add erc721Id's price to the total valuation.
            totalWad += priceWad;

            unchecked { ++i; }
        }

        return totalWad;
    }

    //----------------------------------
    // Oracle Functions

    // @todo Rename to something like _getPriceFrom(oracle...);
    function _queryOracle(address oracle) private returns (uint) {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(oracle).getData();

        if (!valid || price == 0) {
            // Revert if oracle is invalid or price is zero.
            revert("Invalid Oracle");
        } else {
            // Otherwise return the price.
            return price;
        }
    }

    //----------------------------------
    // ERC721Id Functions

    function _hashOfERC721Id(ERC721Id memory erc721Id)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(erc721Id));
    }

    //----------------------------------
    // Minting Functions

    function _commitERC20TokenMint(
        address erc20,
        address to,
        uint amount
    ) private {
        uint vestingDuration = vestingDurationPerERC20[erc20];

        if (vestingDuration == 0) {
            // No vesting, mint tokens directly to user.
            _token.mint(to, amount);
        } else {
            // Vest token via vesting vault.
            _token.mint(address(this), amount);

            // Note that the tokens are fetched from address(this) to the
            // vesting vault.
            _vestingVault.depositFor(
                to,
                amount,
                vestingDuration
            );
        }
    }

    function _commitERC721IdTokenMint(
        bytes32 erc721IdHash,
        address to,
        uint amount
    ) private {
        uint vestingDuration = vestingDurationPerERC721Id[erc721IdHash];

        if (vestingDuration == 0) {
            // No vesting, mint tokens directly to user.
            _token.mint(to, amount);
        } else {
            // Vest token via vesting vault.
            _token.mint(address(this), amount);

            // Note that the tokens are fetched from address(this) to the
            // vesting vault.
            _vestingVault.depositFor(
                to,
                amount,
                vestingDuration
            );
        }
    }

    //----------------------------------
    // Discount Functions

    function _applyDiscount(address erc20, uint amount) private returns (uint) {
        uint discount = discountPerERC20[erc20];

        return discount == 0
            ? amount
            : amount + (amount * discount) / BPS;
    }

}
