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

    /// @dev If max is 0 it's treated as infinte, i.e. no maximum set.
    mapping(address => uint) public bondingLimitPerERC20;

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
        bool valid;
        (/*price*/, valid) = _queryOracle(tokenOracle_);
        require(valid);

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
        _bondERC20(msg.sender, msg.sender, erc20, erc20Amount);
    }

    function bondERC20For(
        address to,
        address erc20,
        uint erc20Amount
    ) external {
        _bondERC20(msg.sender, to, erc20, erc20Amount);
    }

    function bondERC20All(address erc20) external {
        _bondERC20(
            msg.sender,
            msg.sender,
            erc20,
            ERC20(erc20).balanceOf(msg.sender)
        );
    }

    function bondERC20AllFor(address to, address erc20) external {
        _bondERC20(
            msg.sender,
            to,
            erc20,
            ERC20(erc20).balanceOf(msg.sender)
        );
    }

    //--------------
    // Bond ERC721Id Functions

    function bondERC721Id(ERC721Id memory erc721Id) external {
        _bondERC721Id(msg.sender, msg.sender, erc721Id);
    }

    function bondERC721IdFor(address to, ERC721Id memory erc721Id) external {
        _bondERC721Id(msg.sender, to, erc721Id);
    }

    //----------------------------------
    // Unbond Functions

    //--------------
    // Unbond ERC20 Functions

    function unbondERC20(address erc20, uint tokenAmount) external {
        _unbondERC20(msg.sender, msg.sender, erc20, tokenAmount);
    }

    function unbondERC20To(
        address to,
        address erc20,
        uint tokenAmount
    ) external {
        _unbondERC20(msg.sender, to, erc20, tokenAmount);
    }

    function unbondERC20All(address erc20) external {
        _unbondERC20(
            msg.sender,
            msg.sender,
            erc20,
            _token.balanceOf(address(this))
        );
    }

    function unbondERC20AllTo(address to, address erc20) external {
        _unbondERC20(
            msg.sender,
            to,
            erc20,
            _token.balanceOf(address(this))
        );
    }

    //--------------
    // Unbond ERC721Id Functions

    function unbondERC721Id(
        ERC721Id memory erc721Id,
        uint tokenAmount
    ) external {
        _unbondERC721Id(msg.sender, msg.sender, erc721Id, tokenAmount);
    }

    function unbondERC721IdTo(
        address to,
        ERC721Id memory erc721Id,
        uint tokenAmount
    ) external {
        _unbondERC721Id(msg.sender, to, erc721Id, tokenAmount);
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
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert("Invalid oracle");
        }

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
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert("Invalid oracle");
        }

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
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert("Oracle invalid");
        }

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
        bool valid;
        (/*price*/, valid) = _queryOracle(oracle);
        if (!valid) {
            revert("Oracle invalid");
        }

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
        isBondableERC20(erc20)
        isNotExceedingERC20BondingLimit(erc20, erc20Amount)
        validRecipient(to)
        validAmount(erc20Amount)
        onBeforeUpdateBacking(true)
    {
        // Fetch amount of erc20 tokens.
        ERC20(erc20).safeTransferFrom(from, address(this), erc20Amount);

        // Query erc20's price oracle.
        bool valid;
        uint priceWad;
        (priceWad, valid) = _queryOracle(oraclePerERC20[erc20]);
        if (!valid) {
            revert("Invalid Oracle");
        }

        // Calculate the total value of erc20 tokens bonded.
        uint valuationWad = (erc20Amount * priceWad) / 1e18;

        // Query token's price oracle.
        // Note that the priceWad and valid variables are re-used.
        (priceWad, valid) = _queryOracle(_tokenOracle);
        if (!valid) {
            revert("Invalid Token Oracle");
        }

        // Calculate the number of tokens to mint (no discount applied yet).
        uint toMint = (valuationWad * priceWad) / BPS;

        // Add discount if applicable.
        uint discount = discountPerERC20[erc20];
        if (discount != 0) {
            toMint += (toMint * discount) / BPS;
        }

        // Mint tokens.
        _commitTokenMint(to, toMint, vestingDurationPerERC20[erc20]);
    }

    function _bondERC721Id(
        ERC721Id memory erc721Id,
        address from,
        address to
    )
        private
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
        bool valid;
        uint priceWad;
        (priceWad, valid) = _queryOracle(oraclePerERC721Id[erc721IdHash]);
        if (!valid) {
            revert("Invalid Oracle");
        }

        // Note that the price equals the token amount to mint because the
        // amount bonded is always 1 (no discount applied yet).
        uint toMint = priceWad;

        // Query token's price oracle.
        // Note that the priceWad and valid variables are re-used.
        (priceWad, valid) = _queryOracle(_tokenOracle);
        if (!valid) {
            revert("Invalid Token Oracle");
        }

        // Add discount if applicable.
        uint discount = discountPerERC721Id[erc721IdHash];
        if (discount != 0) {
            toMint += (toMint * discount) / BPS;
        }

        // Mint tokens.
        _commitTokenMint(to, toMint, vestingDurationPerERC721Id[erc721IdHash]);
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
        bool valid;
        uint priceWad;
        (priceWad, valid) = _queryOracle(_tokenOracle);
        if (!valid) {
            revert("Invalid Token Oracle");
        }

        // Calculate valuation of tokens to burn.
        uint tokenValue = (tokenAmount * priceWad) / 1e18;

        // Query erc20's price oracle.
        // Note that the priceWad and valid variables are re-used.
        (priceWad, valid) = _queryOracle(_tokenOracle);
        if (!valid) {
            revert("Invalid Oracle");
        }

        // Calculate the amount of erc20 tokens to withdraw.
        uint erc20Amount = (tokenValue * 1e18) / priceWad;

        // @todo Check that erc20Amount non-zero.

        // Revert if reserve's erc20 tokens balance insufficient.
        // @todo Should also have lower limit per ERC20 mapping!
        if (ERC20(erc20).balanceOf(address(this)) < erc20Amount) {
            revert("Insufficient Reserve Balance");
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
        // Query token's price oracle.
        bool valid;
        uint priceWad;
        (priceWad, valid) = _queryOracle(_tokenOracle);
        if (!valid) {
            revert("Invalid Token Oracle");
        }

        // Calculate valuation of tokens to burn.
        uint tokenValue = (tokenAmount * priceWad) / 1e18;

        // Query erc721Id's price oracle.
        // Note that the priceWad and valid variables are re-used.
        (priceWad, valid) = _queryOracle(oraclePerERC721Id[erc721IdHash]);
        if (!valid) {
            revert("Invalid Oracle");
        }

        // Revert if valuation of token amount not sufficient.
        if (priceWad > tokenValue) {
            revert("Insufficient Token Amount");
        }

        // Withdraw ERC721Id and burn tokens.
        ERC721(erc721Id.erc721).safeTransfer(to, erc721.id);
        _token.burn(from, tokenAmount);
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
        bool valid;
        uint priceWad;
        (priceWad, valid) = _queryOracle(_tokenOracle);
        if (!valid) {
            revert("Token Oracle invalid");
        }

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
            (priceWad, valid) = _queryOracle(oraclePerERC20[erc20]);
            if (!valid) {
                revert("Invalid oracle");
            }

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
            (priceWad, valid) = _queryOracle(oraclePerERC721Id[erc721IdHash]);
            if (!valid) {
                revert("Invalid oracle");
            }

            // Add erc721Id's price to the total valuation.
            totalWad += priceWad;

            unchecked { ++i; }
        }

        return totalWad;
    }

    //----------------------------------
    // Oracle Functions

    function _queryOracle(address oracle) private returns (uint, bool) {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(oracle).getData();

        if (!valid || price == 0) {
            // Return (0, false) if oracle is invalid or price is zero.
            return (0, false);
        } else {
            // Otherwise return (price, true).
            return (price, true);
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

    function _commitTokenMint(
        address to,
        uint amount,
        uint vestingDuration
    ) private {
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

}
