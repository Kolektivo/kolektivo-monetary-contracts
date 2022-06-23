// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

// External Interfaces.
import {IERC20} from "./interfaces/_external/IERC20.sol";

// External Contracts.
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

// External Libraries.
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// Internal Interfaces.
import {IOracle} from "./interfaces/IOracle.sol";
import {IVestingVault} from "./interfaces/IVestingVault.sol";
import {IReserve2Owner, IReserve2} from "./interfaces/IReserve2Owner.sol";

// Internal Libraries.
import {Wad} from "./lib/Wad.sol";

/**
 Notes:
    - The term "supported" in context of the Reserve means that the reserve
      has a price oracle for the asset (ERC20, ERC721Id) and takes the
      reserve's balance for this asset into account for the backing
      calculation.
    - KTT (the elastic token produces by the Treasury) does not have a
      special treatment anymore. It needs to be supported by adding a
      price oracle.
    - A max/min un/bonding is implemented. ERC20 tokens are not bondable
      if it would exceed the max balance of this token the Reserve is allowed
      to hold. Same goes for min and unbonding operations.
    - For the backing calculation the price oracle of the "token" (KOL) is
      taken into account to calculate the current backing.
    - Naming Conventions:
        - token: The token the Reserve mints/burns.
        - asset: ERC20 or ERC721Id token.
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
contract Reserve2 is TSOwnable, IReserve2Owner {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0) || to == address(this)) {
            revert("Invalid recipient");
        }
        _;
    }

    /// @dev Modifier to guarantee token amount is valid.
    modifier validAmount(uint amount) {
        if (amount == 0) {
            revert("Invalid amount");
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable for supported
    ///      ERC20 token.
    modifier isSupportedERC20(address erc20) {
        if (oraclePerERC20[erc20] == address(0)) {
            revert("ERC20 not supported");
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable for supported
    ///      ERC721Id instances.
    modifier isSupportedERC721Id(ERC721Id memory erc721) {
        if (oraclePerERC721Id[_hashOfERC721Id(erc721)] == address(0)) {
            revert("ERC721Id not supported");
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with bondable
    ///      ERC20 token.
    modifier isBondableERC20(address erc20) {
        if (!isERC20Bondable[erc20]) {
            revert("ERC20 not bondable");
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with bondable
    ///      ERC721Id instances.
    modifier isBondableERC721Id(ERC721Id memory erc721Id) {
        if (!isERC721IdBondable[_hashOfERC721Id(erc721Id)]) {
            revert("ERC721Id not bondable");
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with unbondable
    ///      ERC20 token.
    modifier isUnbondableERC20(address erc20) {
        if (!isERC20Unbondable[erc20]) {
            revert("ERC20 not unbondable");
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with unbondable
    ///      ERC721Id instances.
    modifier isUnbondableERC721Id(ERC721Id memory erc721Id) {
        if (!isERC721IdUnbondable[_hashOfERC721Id(erc721Id)]) {
            revert("ERC721Id not unbondable");
        }
        _;
    }

    /// @dev Modifier to guarantee an ERC20 token bonding with given amount
    ///      does not exceed the bonding limit.
    modifier isNotExceedingERC20BondingLimit(address erc20, uint amount) {
        uint balance = ERC20(erc20).balanceOf(address(this));
        uint limit = bondingLimitPerERC20[erc20];

        // Note that a limit of zero is interpreted as limit given.
        if (limit != 0 && balance + amount > limit) {
            revert("ERC20 bond limit reached");
        }

        _;
    }

    /// @dev Modifier to update the internal backing ratio after a function
    ///      execution.
    /// @param requireMinBacking Whether the call should revert if the minimal
    ///                          backing requirement is not met anymore.
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

    //--------------------------------------------------------------------------
    // Storage

    //----------------------------------
    // Token Storage

    /// @inheritdoc IReserve2
    address public tokenOracle;

    /// @inheritdoc IReserve2
    address public vestingVault;

    //----------------------------------
    // Asset Mappings

    address[] public supportedERC20s;
    ERC721Id[] public supportedERC721Ids;

    // address of type ERC20 => address of type IOracle.
    mapping(address => address) public oraclePerERC20;
    // ERC721Id => address of type IOracle.
    mapping(bytes32 => address) public oraclePerERC721Id;

    //----------------------------------
    // Un/Bonding Mappings

    mapping(address => bool) public isERC20Bondable;
    mapping(address => bool) public isERC20Unbondable;

    mapping(bytes32 => bool) public isERC721IdBondable;
    mapping(bytes32 => bool) public isERC721IdUnbondable;

    /// @dev If limit is 0 it's treated as infinte, i.e. no maximum set.
    mapping(address => uint) public bondingLimitPerERC20;

    mapping(address => uint) public unbondingLimitPerERC20;

    //----------------------------------
    // Discount Mappings

    mapping(address => uint) public discountPerERC20;
    mapping(bytes32 => uint) public discountPerERC721Id;

    //----------------------------------
    // Vesting Mappings

    mapping(address => uint) public vestingDurationPerERC20;
    mapping(bytes32 => uint) public vestingDurationPerERC721Id;

    //----------------------------------
    // Reserve Management

    /// @dev The percentage, denominated in bps, of token supply backed by
    ///      assets held in the reserve.
    uint private _backing;

    /// @inheritdoc IReserve2
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

        // Check token oracle's validity.
        require(_oracleIsValid(tokenOracle_));

        // Check vesting vault's validity.
        require(IVestingVault(vestingVault_).token() == token_);

        // Set storage.
        _token = IERC20MintBurn(token_);
        tokenOracle = tokenOracle_;
        vestingVault = vestingVault_;
        minBacking = minBacking_;

        // Set current backing to 100%;
        _backing = BPS;

        // Give vesting vault infinite approval.
        IERC20MintBurn(token_).approve(vestingVault_, type(uint).max);

        // Notify off-chain services.
        emit SetTokenOracle(address(0), tokenOracle_);
        emit SetVestingVault(address(0), vestingVault_);
        emit SetMinBacking(0, minBacking_);
    }

    //--------------------------------------------------------------------------
    // User Mutating Functions

    //----------------------------------
    // Bond Functions

    //--------------
    // Bond ERC20 Functions

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
        ERC721Id memory erc721Id
    ) external {
        _unbondERC721Id(erc721Id, msg.sender, msg.sender);
    }

    function unbondERC721IdTo(
        ERC721Id memory erc721Id,
        address to
    ) external {
        _unbondERC721Id(erc721Id, msg.sender, to);
    }

    //----------------------------------
    // Reserve Functions

    /// @inheritdoc IReserve2
    function reserveStatus() external returns (uint, uint, uint) {
        return (_reserveValuation(), _supplyValuation(), _backing);
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @inheritdoc IReserve2
    function token() external view returns (address) {
        return address(_token);
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Emergency Functions
    // For more info see Issue #2.

    /// @inheritdoc IReserve2Owner
    function executeTx(address target, bytes memory data)
        external
        onlyOwner
    {
        bool success;
        (success, /*returnData*/) = target.call(data);
        require(success);
    }

    //----------------------------------
    // Token Management

    /// @inheritdoc IReserve2Owner
    function setTokenOracle(address tokenOracle_) external onlyOwner {
        if (tokenOracle != tokenOracle_) {
            // Check oracle's validity.
            require(_oracleIsValid(tokenOracle_));

            emit SetTokenOracle(tokenOracle, tokenOracle_);
            tokenOracle = tokenOracle_;
        }
    }

    //----------------------------------
    // Asset Management

    /// @inheritdoc IReserve2Owner
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

        // Check oracle's validity.
        require(_oracleIsValid(oracle));

        // Add erc20 and oracle to mappings.
        supportedERC20s.push(erc20);
        oraclePerERC20[erc20] = oracle;

        // Notify off-chain services.
        emit ERC20MarkedAsSupported(erc20);
        emit SetERC20Oracle(erc20, address(0), oracle);
    }

    /// @inheritdoc IReserve2Owner
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

        // Check oracle's validity.
        require(_oracleIsValid(oracle));

        // Add erc721Id and oracle to mappings.
        supportedERC721Ids.push(erc721Id);
        oraclePerERC721Id[erc721IdHash] = oracle;

        // Notify off-chain services.
        emit ERC721IdMarkedAsSupported(erc721Id);
        emit SetERC721IdOracle(erc721Id, address(0), oracle);
    }

    /// @inheritdoc IReserve2Owner
    function unsupportERC20(address erc20) external onlyOwner {
        // Do nothing if erc20 is already not supported.
        // Note that we do not use the isSupportedERC20 modifier to be idempotent.
        if (oraclePerERC20[erc20] == address(0)) {
            return;
        }

        // Remove erc20's oracle and notify off-chain services.
        emit SetERC20Oracle(erc20, oraclePerERC20[erc20], address(0));
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

                emit ERC20MarkedAsUnsupported(erc20);
                break;
            }

            unchecked { ++i; }
        }
    }

    /// @inheritdoc IReserve2Owner
    function unsupportERC721Id(ERC721Id memory erc721Id) external onlyOwner {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Do nothing if erc721 is already not supported.
        // Note that we do not use the isSupportedERC721Id modifier to be idempotent.
        if (oraclePerERC721Id[erc721IdHash] == address(0)) {
            return;
        }

        // Remove erc721Id's oracle and notify off-chain services.
        emit SetERC721IdOracle(erc721Id, oraclePerERC721Id[erc721IdHash], address(0));
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

                emit ERC721IdMarkedAsUnsupported(erc721Id);
                break;
            }

            unchecked { ++i; }
        }
    }

    /// @inheritdoc IReserve2Owner
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

        // Check oracle's validity.
        require(_oracleIsValid(oracle));

        // Update erc20's oracle and notify off-chain services.
        oraclePerERC20[erc20] = oracle;
        emit SetERC20Oracle(erc20, oldOracle, oracle);
    }

    /// @inheritdoc IReserve2Owner
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

        // Check oracle's validity.
        require(_oracleIsValid(oracle));

        // Update erc721Id's oracle and notify off-chain services.
        oraclePerERC721Id[erc721IdHash] = oracle;
        emit SetERC721IdOracle(erc721Id, oldOracle, oracle);
    }

    //----------------------------------
    // Un/Bonding Management

    // @todo Should we require that the erc20/erc721Id is already supported before
    //       being able to add un/bonding support, discount and vesting?

    /// @inheritdoc IReserve2Owner
    function supportERC20ForBonding(address erc20, bool support)
        external
        onlyOwner
    {
        bool oldSupport = isERC20Bondable[erc20];

        if (support != oldSupport) {
            isERC20Bondable[erc20] = support;
            emit SetERC20BondingSupport(erc20, support);
        }
    }

    /// @inheritdoc IReserve2Owner
    function supportERC721IdForBonding(ERC721Id memory erc721Id, bool support)
        external
        onlyOwner
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        bool oldSupport = isERC721IdBondable[erc721IdHash];

        if (support != oldSupport) {
            isERC721IdBondable[erc721IdHash] = support;
            emit SetERC721IdBondingSupport(erc721Id, support);
        }
    }

    /// @inheritdoc IReserve2Owner
    function supportERC20ForUnbonding(address erc20, bool support)
        external
        onlyOwner
    {
        bool oldSupport = isERC20Unbondable[erc20];

        if (support != oldSupport) {
            isERC20Bondable[erc20] = support;
            emit SetERC20UnbondingSupport(erc20, support);
        }
    }

    /// @inheritdoc IReserve2Owner
    function supportERC721IdForUnbonding(ERC721Id memory erc721Id, bool support)
        external
        onlyOwner
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        bool oldSupport = isERC721IdUnbondable[erc721IdHash];

        if (support != oldSupport) {
            isERC721IdUnbondable[erc721IdHash] = support;
            emit SetERC721IdUnbondingSupport(erc721Id, support);
        }
    }

    /// @inheritdoc IReserve2Owner
    function setERC20BondingLimit(address erc20, uint limit)
        external
        onlyOwner
    {
        uint oldLimit = bondingLimitPerERC20[erc20];

        if (limit != oldLimit) {
            emit SetERC20BondingLimit(erc20, oldLimit, limit);
            bondingLimitPerERC20[erc20] = limit;
        }
    }

    /// @inheritdoc IReserve2Owner
    function setERC20UnbondingLimit(address erc20, uint limit)
        external
        onlyOwner
    {
        uint oldLimit = unbondingLimitPerERC20[erc20];

        if (limit != oldLimit) {
            emit SetERC20UnbondingLimit(erc20, oldLimit, limit);
            unbondingLimitPerERC20[erc20] = limit;
        }
    }

    //----------------------------------
    // Discount Management

    /// @inheritdoc IReserve2Owner
    function setDiscountForERC20(address erc20, uint discount)
        external
        onlyOwner
    {
        uint oldDiscount = discountPerERC20[erc20];

        if (discount != oldDiscount) {
            emit SetERC20Discount(erc20, oldDiscount, discount);
            discountPerERC20[erc20] = discount;
        }
    }

    /// @inheritdoc IReserve2Owner
    function setDiscountForERC721Id(ERC721Id memory erc721Id, uint discount)
        external
        onlyOwner
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        uint oldDiscount = discountPerERC721Id[erc721IdHash];

        if (discount != oldDiscount) {
            emit SetERC721IdDiscount(erc721Id, oldDiscount, discount);
            discountPerERC721Id[erc721IdHash] = discount;
        }
    }

    //----------------------------------
    // Vesting Management

    /// @inheritdoc IReserve2Owner
    function setVestingVault(address vestingVault_) external onlyOwner {
        if (vestingVault != vestingVault_) {
            // Check new vesting vault's validity.
            require(IVestingVault(vestingVault_).token() == address(_token));

            // Remove old vesting vault's approval.
            _token.approve(vestingVault, 0);

            // Give new vesting vault infinite approval.
            _token.approve(vestingVault_, type(uint).max);

            emit SetVestingVault(vestingVault, vestingVault_);
            vestingVault = vestingVault_;
        }
    }

    /// @inheritdoc IReserve2Owner
    function setVestingForERC20(address erc20, uint vestingDuration)
        external
        onlyOwner
    {
        uint oldVestingDuration = vestingDurationPerERC20[erc20];

        if (vestingDuration != oldVestingDuration) {
            emit SetERC20Vesting(erc20, oldVestingDuration, vestingDuration);
            vestingDurationPerERC20[erc20] = vestingDuration;
        }
    }

    /// @inheritdoc IReserve2Owner
    function setVestingForERC721Id(
        ERC721Id memory erc721Id,
        uint vestingDuration
    ) external onlyOwner {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        uint oldVestingDuration = vestingDurationPerERC721Id[erc721IdHash];

        if (vestingDuration != oldVestingDuration) {
            emit SetERC721IdVesting(
                erc721Id,
                oldVestingDuration,
                vestingDuration
            );
            vestingDurationPerERC721Id[erc721IdHash] = vestingDuration;
        }
    }

    //----------------------------------
    // Reserve Management

    /// @inheritdoc IReserve2Owner
    function setMinBacking(uint minBacking_) external onlyOwner {
        require(minBacking_ != 0);
        // @todo Disallow setting minBacking lower than current backing?

        if (minBacking != minBacking_) {
            emit SetMinBacking(minBacking, minBacking_);
            minBacking = minBacking_;
        }
    }

    /// @inheritdoc IReserve2Owner
    function incurDebt(uint amount)
        external
        onBeforeUpdateBacking(true)
        onlyOwner
    {
        // Mint tokens, i.e. create debt.
        _token.mint(msg.sender, amount);

        // Notify off-chain services.
        emit DebtIncurred(amount);
    }

    /// @inheritdoc IReserve2Owner
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
        emit DebtPayed(amount);
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

        // Compute amount of tokens to mint.
        uint amount = _computeMintAmountGivenERC20(erc20, erc20Amount);

        // Mint tokens.
        _commitTokenMintGivenERC20(erc20, to, amount);
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

        // Comput amount of tokens to mint.
        uint amount = _computeMintAmountGivenERC721Id(erc721IdHash);

        // Mint tokens.
        _commitTokenMintGivenERC721Id(erc721IdHash, to, amount);
    }

    //----------------------------------
    // Unbond Functions

    // @todo Note that unbonding does not have any vesting options.

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
        // Calculate valuation of tokens to burn.
        uint tokenValue = (tokenAmount * _priceOfToken()) / 1e18;

        // Calculate the amount of erc20 tokens to withdraw.
        uint erc20Amount = (tokenValue * 1e18) / _priceOfERC20(erc20);

        // Revert if balance not sufficient.
        uint balance = ERC20(erc20).balanceOf(address(this));
        if (balance < erc20Amount) {
            revert("ERC20 unbonding limit exceeded");
        }

        // Revert if unbonding limit exceeded.
        uint limit = unbondingLimitPerERC20[erc20];
        if (balance - erc20Amount < limit) {
            revert("ERC20 unbonding limit exceeded");
        }

        // Withdraw erc20s and burn tokens.
        ERC20(erc20).safeTransfer(to, erc20Amount);
        _token.burn(from, tokenAmount);
    }

    function _unbondERC721Id(
        ERC721Id memory erc721Id,
        address from,
        address to
    )
        private
        // Note that if an ERC721Id is unbondable, it is also supported.
        // isSupportedERC721Id(erc721Id)
        isUnbondableERC721Id(erc721Id)
        validRecipient(to)
        onBeforeUpdateBacking(true)
    {
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Query erc721Id's price oracle.
        uint priceWad = _priceOfERC721Id(erc721IdHash);

        // Calculate the amount of tokens to burn.
        uint tokenAmount = (priceWad / _priceOfToken()) * 1e18;

        // Burn tokens and withdraw ERC721Id.
        // Note that the ERC721 transfer triggers a callback if the recipient
        // is a contract. However, reentry should not be a problem as the
        // transfer is the last operation executed.
        _token.burn(from, tokenAmount);
        ERC721(erc721Id.erc721).safeTransferFrom(
            address(this),
            to,
            erc721Id.id
        );
    }

    function _computeMintAmountGivenERC20(address erc20, uint amount)
        private
        returns (uint)
    {
        uint priceWad = _priceOfERC20(erc20);

        // Calculate the total value of erc20 tokens.
        uint valuationWad = (amount * priceWad) / 1e18;

        // Calculate the number of tokens to mint (no discount applied yet).
        uint toMint = (valuationWad * _priceOfToken()) / BPS;

        // Apply discount.
        toMint = _applyDiscountForERC20(erc20, toMint);

        return toMint;
    }

    function _computeMintAmountGivenERC721Id(bytes32 erc721IdHash)
        private
        returns (uint)
    {
        uint priceWad = _priceOfERC721Id(erc721IdHash);

        // Note that price equals valuation because the amount of tokens
        // bonded is always 1 for an erc721Id.
        uint valuationWad = priceWad;

        // Calculate the number of tokens to mint (no discount applied yet).
        uint toMint = (valuationWad * _priceOfToken()) / BPS;

        // Apply discount.
        toMint = _applyDiscountForERC721Id(erc721IdHash, toMint);

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
        // Calculate and return total valuation of tokens created.
        return (_token.totalSupply() * _priceOfToken()) / 1e18;
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
            priceWad = _priceOfERC20(erc20);

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
            priceWad = _priceOfERC721Id(erc721IdHash);

            // Add erc721Id's price to the total valuation.
            totalWad += priceWad;

            unchecked { ++i; }
        }

        return totalWad;
    }

    //----------------------------------
    // Oracle Functions

    function _oracleIsValid(address oracle) private returns (bool) {
        bool valid;
        uint price;
        (price, valid) = IOracle(oracle).getData();

        return valid && price != 0;
    }

    function _priceOfToken() private returns (uint) {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(tokenOracle).getData();

        if (!valid || price == 0) {
            // Revert if oracle is invalid or price is zero.
            revert("Invalid Oracle");
        }

        return price;
    }

    function _priceOfERC20(address erc20) private returns (uint) {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(oraclePerERC20[erc20]).getData();

        if (!valid || price == 0) {
            // Revert if oracle is invalid or price is zero.
            revert("Invalid Oracle");
        }

        return price;
    }

    function _priceOfERC721Id(bytes32 erc721IdHash) private returns (uint) {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(oraclePerERC721Id[erc721IdHash]).getData();

        if (!valid || price == 0) {
            // Revert if oracle is invalid or price is zero.
            revert("Invalid Oracle");
        }

        return price;
    }

    //----------------------------------
    // Minting Functions

    function _commitTokenMintGivenERC20(
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
            IVestingVault(vestingVault).depositFor(
                to,
                amount,
                vestingDuration
            );
        }
    }

    function _commitTokenMintGivenERC721Id(
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
            IVestingVault(vestingVault).depositFor(
                to,
                amount,
                vestingDuration
            );
        }
    }

    //----------------------------------
    // Discount Functions

    function _applyDiscountForERC20(address erc20, uint amount)
        private
        view
        returns (uint)
    {
        uint discount = discountPerERC20[erc20];

        return discount == 0
            ? amount
            : amount + (amount * discount) / BPS;
    }

    function _applyDiscountForERC721Id(bytes32 erc721IdHash, uint amount)
        private
        view
        returns (uint)
    {
        uint discount = discountPerERC721Id[erc721IdHash];

        return discount == 0
            ? amount
            : amount + (amount * discount) / BPS;
    }

    //----------------------------------
    // ERC721Id Helper Functions

    function _hashOfERC721Id(ERC721Id memory erc721Id)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(erc721Id));
    }

}
