// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

// External Interfaces.
import {IERC20} from "./interfaces/_external/IERC20.sol";
import {IERC721Receiver} from "./interfaces/_external/IERC721Receiver.sol";

// External Contracts.
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";

// External Libraries.
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

// Internal Interfaces.
import {IOracle} from "./interfaces/IOracle.sol";
import {ITimeLockVault} from "./interfaces/ITimeLockVault.sol";
import {IReserve} from "./interfaces/IReserve.sol";

// Internal Libraries.
import {Wad} from "./lib/Wad.sol";

interface IERC20MintBurn is IERC20 {
    function mint(address to, uint amount) external;

    function burn(address from, uint amount) external;
}

/**
 * @title Reserve
 *
 * @dev The Kolektivo reserve manages a fractional receipt money using ERC20
 *      tokens and/or ERC721 NFTs as collateral.
 *
 *      The contract is only usable by an owner. The owner is eligible to:
 *      - Incur debt, i.e. minting tokens without bonding assets
 *      - Pay debt, i.e. burn token without unbonding assets
 *      - Bond and redeem ERC20 tokens and/or ERC721 NFTs
 *      - Change asset configurations
 *
 *      Note:
 *      - The term "registered" means that the reserve has a price oracle for the
 *        asset (ERC20, ERC721Id) and takes the reserve's balance of this asset
 *        into account for the backing ratio computation.
 *      - The elastic token produced by the Kolektivo treasury does NOT have any
 *        special treatment. It needs to be supported by adding a price oracle
 *        like any other asset.
 *
 *      Naming conventions:
 *      - token : The token the reserve mints/burns, i.e. the fractional receipt
 *                money.
 *      - asset : ERC20 token or ERC721 NFT
 *
 * @author byterocket
 */
contract Reserve is TSOwnable, IReserve, IERC721Receiver {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Modifier to guarantee token recipient is valid.
    modifier validRecipient(address to) {
        if (to == address(0) || to == address(this)) {
            revert Reserve__InvalidRecipient();
        }
        _;
    }

    /// @dev Modifier to guarantee token amount is valid.
    modifier validAmount(uint amount) {
        if (amount == 0) {
            revert Reserve__InvalidAmount();
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with registered
    ///      ERC20 token.
    modifier isRegisteredERC20(address erc20) {
        if (oraclePerERC20[erc20] == address(0)) {
            revert Reserve__ERC20NotRegistered();
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with registered
    ///      ERC721Id instances.
    modifier isRegisteredERC721Id(address erc721, uint id) {
        if (oraclePerERC721Id[erc721][id] == address(0)) {
            revert Reserve__ERC721IdNotRegistered();
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with bondable
    ///      ERC20 token.
    modifier isBondableERC20(address erc20) {
        if (!isERC20Bondable[erc20]) {
            revert Reserve__ERC20NotBondable();
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with bondable
    ///      ERC721Id instances.
    modifier isBondableERC721Id(address erc721, uint id) {
        if (!isERC721IdBondable[erc721][id]) {
            revert Reserve__ERC721IdNotBondable();
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with redeemable
    ///      ERC20 token.
    modifier isRedeemableERC20(address erc20) {
        if (!isERC20Redeemable[erc20]) {
            revert Reserve__ERC20NotRedeemable();
        }
        _;
    }

    /// @dev Modifier to guarantee function is only callable with redeemable
    ///      ERC721Id instances.
    modifier isRedeemableERC721Id(address erc721, uint id) {
        if (!isERC721IdRedeemable[erc721][id]) {
            revert Reserve__ERC721IdNotRedeemable();
        }
        _;
    }

    /// @dev Modifier to guarantee an ERC20 token bonding with given amount
    ///      does not exceed the bonding limit.
    modifier isNotExceedingERC20BondingLimit(address erc20, uint amount) {
        uint balance = ERC20(erc20).balanceOf(address(this));
        uint limit = bondingLimitPerERC20[erc20];

        // Note that a limit of zero is interpreted as no limit given.
        if (limit != 0 && balance + amount > limit) {
            revert Reserve__ERC20BondingLimitExceeded();
        }

        _;
    }

    /// @dev Modifier to update the internal backing ratio after a function
    ///      execution.
    /// @param requireMinBacking Whether the call should revert if the minimal
    ///                          backing requirement is not met.
    modifier onBeforeUpdateBacking(bool requireMinBacking) {
        _;

        uint backing;
        (, , backing) = _reserveStatus();

        if (requireMinBacking && backing < minBacking) {
            revert Reserve__MinimumBackingLimitExceeded();
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

    /// @inheritdoc IReserve
    address public tokenOracle;

    /// @inheritdoc IReserve
    address public timeLockVault;

    //----------------------------------
    // Asset Mappings

    /// @inheritdoc IReserve
    address[] public registeredERC20s;

    /// @inheritdoc IReserve
    ERC721Id[] public registeredERC721Ids;

    /// @inheritdoc IReserve
    mapping(address => address) public oraclePerERC20;

    /// @inheritdoc IReserve
    mapping(address => mapping(uint => address)) public oraclePerERC721Id;

    /// @inheritdoc IReserve
    mapping(address => AssetType) public assetTypeOfERC20;

    /// @inheritdoc IReserve
    mapping(address => RiskLevel) public riskLevelOfERC20;

    //----------------------------------
    // Bonding & Redeeming Mappings

    /// @inheritdoc IReserve
    mapping(address => bool) public isERC20Bondable;

    /// @inheritdoc IReserve
    mapping(address => mapping(uint => bool)) public isERC721IdBondable;

    /// @inheritdoc IReserve
    mapping(address => bool) public isERC20Redeemable;

    /// @inheritdoc IReserve
    mapping(address => mapping(uint => bool)) public isERC721IdRedeemable;

    /// @inheritdoc IReserve
    mapping(address => uint) public bondingLimitPerERC20;

    /// @inheritdoc IReserve
    mapping(address => uint) public redeemLimitPerERC20;

    //----------------------------------
    // Discount Mappings

    /// @inheritdoc IReserve
    mapping(address => uint) public bondingDiscountPerERC20;

    /// @inheritdoc IReserve
    mapping(address => mapping(uint => uint)) public bondingDiscountPerERC721Id;

    //----------------------------------
    // Time Lock Mappings

    /// @inheritdoc IReserve
    mapping(address => uint) public bondingTimeLockDurationPerERC20;

    /// @inheritdoc IReserve
    mapping(address => mapping(uint => uint))
        public bondingTimeLockDurationPerERC721Id;

    //----------------------------------
    // Reserve Management

    /// @inheritdoc IReserve
    uint public minBacking;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(
        address token_,
        address tokenOracle_,
        uint minBacking_
    ) {
        // Check token's validity.
        require(token_.code.length != 0);

        // Set storage.
        _token = IERC20MintBurn(token_);
        tokenOracle = tokenOracle_;
        minBacking = minBacking_;
    

        // Notify off-chain services.
        emit SetTokenOracle(address(0), tokenOracle_);
        emit SetMinBacking(0, minBacking_);
        emit BackingUpdated(0, BPS);
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @inheritdoc IReserve
    function reserveStatus()
        external
        view
        returns (
            uint,
            uint,
            uint
        )
    {
        return _reserveStatus();
    }

    /// @inheritdoc IReserve
    function token() external view returns (address) {
        return address(_token);
    }

    /// @inheritdoc IReserve
    function allRegisteredERC20s() external view returns (address[] memory) {
        return registeredERC20s;
    }

    /// @inheritdoc IReserve
    function allRegisteredERC721Ids()
        external
        view
        returns (ERC721Id[] memory)
    {
        return registeredERC721Ids;
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    //--------------------------------------------------------------------------
    // onlyOwner Functions

    //----------------------------------
    // Bond Functions

    //--------------
    // Bond ERC20 Functions

    /// @inheritdoc IReserve
    function bondERC20(address erc20, uint erc20Amount) external onlyOwner {
        _bondERC20(erc20, msg.sender, msg.sender, erc20Amount);
    }

    /// @inheritdoc IReserve
    function bondERC20From(
        address erc20,
        address from,
        uint erc20Amount
    ) external onlyOwner {
        _bondERC20(erc20, from, msg.sender, erc20Amount);
    }

    /// @inheritdoc IReserve
    function bondERC20To(
        address erc20,
        address to,
        uint erc20Amount
    ) external onlyOwner {
        _bondERC20(erc20, msg.sender, to, erc20Amount);
    }

    /// @inheritdoc IReserve
    function bondERC20FromTo(
        address erc20,
        address from,
        address to,
        uint erc20Amount
    ) external onlyOwner {
        _bondERC20(erc20, from, to, erc20Amount);
    }

    /// @inheritdoc IReserve
    function bondERC20All(address erc20) external onlyOwner {
        _bondERC20(
            erc20,
            msg.sender,
            msg.sender,
            ERC20(erc20).balanceOf(msg.sender)
        );
    }

    /// @inheritdoc IReserve
    function bondERC20AllFrom(address erc20, address from) external onlyOwner {
        _bondERC20(erc20, from, msg.sender, ERC20(erc20).balanceOf(from));
    }

    /// @inheritdoc IReserve
    function bondERC20AllTo(address erc20, address to) external onlyOwner {
        _bondERC20(erc20, msg.sender, to, ERC20(erc20).balanceOf(msg.sender));
    }

    /// @inheritdoc IReserve
    function bondERC20AllFromTo(
        address erc20,
        address from,
        address to
    ) external onlyOwner {
        _bondERC20(erc20, from, to, ERC20(erc20).balanceOf(from));
    }

    //--------------
    // Bond ERC721Id Functions

    /// @inheritdoc IReserve
    function bondERC721Id(address erc721, uint id) external onlyOwner {
        _bondERC721Id(erc721, id, msg.sender, msg.sender);
    }

    /// @inheritdoc IReserve
    function bondERC721IdFrom(
        address erc721,
        uint id,
        address from
    ) external onlyOwner {
        _bondERC721Id(erc721, id, from, msg.sender);
    }

    /// @inheritdoc IReserve
    function bondERC721IdTo(
        address erc721,
        uint id,
        address to
    ) external onlyOwner {
        _bondERC721Id(erc721, id, msg.sender, to);
    }

    /// @inheritdoc IReserve
    function bondERC721IdFromTo(
        address erc721,
        uint id,
        address from,
        address to
    ) external onlyOwner {
        _bondERC721Id(erc721, id, from, to);
    }

    //----------------------------------
    // Redeem Functions

    //--------------
    // Redeem ERC20 Functions

    /// @inheritdoc IReserve
    function redeemERC20(address erc20, uint tokenAmount) external onlyOwner {
        _redeemERC20(erc20, msg.sender, msg.sender, tokenAmount);
    }

    /// @inheritdoc IReserve
    function redeemERC20From(
        address erc20,
        address from,
        uint tokenAmount
    ) external onlyOwner {
        _redeemERC20(erc20, from, msg.sender, tokenAmount);
    }

    /// @inheritdoc IReserve
    function redeemERC20To(
        address erc20,
        address to,
        uint tokenAmount
    ) external onlyOwner {
        _redeemERC20(erc20, msg.sender, to, tokenAmount);
    }

    /// @inheritdoc IReserve
    function redeemERC20FromTo(
        address erc20,
        address from,
        address to,
        uint tokenAmount
    ) external onlyOwner {
        _redeemERC20(erc20, from, to, tokenAmount);
    }

    /// @inheritdoc IReserve
    function redeemERC20All(address erc20) external onlyOwner {
        _redeemERC20(
            erc20,
            msg.sender,
            msg.sender,
            _token.balanceOf(address(msg.sender))
        );
    }

    /// @inheritdoc IReserve
    function redeemERC20AllFrom(address erc20, address from)
        external
        onlyOwner
    {
        _redeemERC20(erc20, from, msg.sender, _token.balanceOf(address(from)));
    }

    /// @inheritdoc IReserve
    function redeemERC20AllTo(address erc20, address to) external onlyOwner {
        _redeemERC20(
            erc20,
            msg.sender,
            to,
            _token.balanceOf(address(msg.sender))
        );
    }

    /// @inheritdoc IReserve
    function redeemERC20AllFromTo(
        address erc20,
        address from,
        address to
    ) external onlyOwner {
        _redeemERC20(erc20, from, to, _token.balanceOf(address(from)));
    }

    //--------------
    // Redeem ERC721Id Functions

    /// @inheritdoc IReserve
    function redeemERC721Id(address erc721, uint id) external onlyOwner {
        _redeemERC721Id(erc721, id, msg.sender, msg.sender);
    }

    /// @inheritdoc IReserve
    function redeemERC721IdFrom(
        address erc721,
        uint id,
        address from
    ) external onlyOwner {
        _redeemERC721Id(erc721, id, from, msg.sender);
    }

    /// @inheritdoc IReserve
    function redeemERC721IdTo(
        address erc721,
        uint id,
        address to
    ) external onlyOwner {
        _redeemERC721Id(erc721, id, msg.sender, to);
    }

    /// @inheritdoc IReserve
    function redeemERC721IdFromTo(
        address erc721,
        uint id,
        address from,
        address to
    ) external onlyOwner {
        _redeemERC721Id(erc721, id, from, to);
    }

    //----------------------------------
    // Emergency Functions
    // For more info see Issue #2.

    /// @inheritdoc IReserve
    function executeTx(address target, bytes memory data) external onlyOwner {
        bool success;
        (success, /*returnData*/) = target.call(data);
        require(success);
    }

    //----------------------------------
    // Token Management

    /// @inheritdoc IReserve
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

    /// @inheritdoc IReserve
    function registerERC20(
        address erc20,
        address oracle,
        AssetType assetType,
        RiskLevel riskLevel
    ) external onlyOwner {
        // Make sure that erc20's code is non-empty.
        // Note that solmate's SafeTransferLib does not include this check.
        require(erc20.code.length != 0);

        address oldOracle = oraclePerERC20[erc20];

        // Do nothing if erc20 is already registered and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert if erc20 is already registered but oracles differ.
        // Note that the updateOracleForERC20 function should be used for this.
        require(oldOracle == address(0));

        // Check oracle's validity.
        require(_oracleIsValid(oracle));

        // Revert if asset type is invalid.
        require(uint(assetType) <= uint(type(AssetType).max));

        // Revert if risk level is invalid.
        require(uint(riskLevel) <= uint(type(RiskLevel).max));

        // Add erc20 and oracle to mappings.
        registeredERC20s.push(erc20);
        oraclePerERC20[erc20] = oracle;
        assetTypeOfERC20[erc20] = assetType;
        riskLevelOfERC20[erc20] = riskLevel;

        // Notify off-chain services.
        emit ERC20Registered(erc20, assetType, riskLevel);
        emit SetERC20Oracle(erc20, address(0), oracle);
    }

    /// @inheritdoc IReserve
    function registerERC721Id(
        address erc721,
        uint id,
        address oracle
    ) external onlyOwner {
        // Make sure that erc721Id's code is non-empty.
        require(erc721.code.length != 0);

        address oldOracle = oraclePerERC721Id[erc721][id];

        // Do nothing if erc721Id is already registered and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert if erc721Id is already registered but oracles differ.
        // Note that the updateOracleForERC721Id function should be used for this.
        require(oldOracle == address(0));

        // Check oracle's validity.
        require(_oracleIsValid(oracle));

        // Add erc721Id and oracle to mappings.
        registeredERC721Ids.push(ERC721Id(erc721, id));
        oraclePerERC721Id[erc721][id] = oracle;

        // Notify off-chain services.
        emit ERC721IdRegistered(erc721, id);
        emit SetERC721IdOracle(erc721, id, address(0), oracle);
    }

    /// @inheritdoc IReserve
    function deregisterERC20(address erc20) external onlyOwner {
        // Do nothing if erc20 is already deregistered.
        // Note that we do not use the isRegisteredERC20 modifier to be
        // idempotent.
        if (oraclePerERC20[erc20] == address(0)) {
            return;
        }

        // Notify off-chain services.
        emit SetERC20Oracle(erc20, oraclePerERC20[erc20], address(0));

        // Remove erc20's oracle and asset type.
        delete oraclePerERC20[erc20];
        delete assetTypeOfERC20[erc20];
        delete riskLevelOfERC20[erc20];

        // Remove erc20 from the registeredERC20s array.
        uint len = registeredERC20s.length;
        for (uint i; i < len; ) {
            if (erc20 == registeredERC20s[i]) {
                // It not last elem in array, copy last elem to this index.
                if (i < len - 1) {
                    registeredERC20s[i] = registeredERC20s[len - 1];
                }
                registeredERC20s.pop();

                emit ERC20Deregistered(erc20);
                break;
            }

            unchecked { ++i; }
        }
    }

    /// @inheritdoc IReserve
    function deregisterERC721Id(address erc721, uint id) external onlyOwner {
        // Do nothing if erc721 is already deregistered.
        // Note that we do not use the isRegisteredERC721Id modifier to be
        // idempotent.
        if (oraclePerERC721Id[erc721][id] == address(0)) {
            return;
        }

        // Remove erc721Id's oracle and notify off-chain services.
        emit SetERC721IdOracle(
            erc721,
            id,
            oraclePerERC721Id[erc721][id],
            address(0)
        );
        delete oraclePerERC721Id[erc721][id];

        // Remove erc721Id from the registeredERC721Ids array.
        uint len = registeredERC721Ids.length;
        for (uint i; i < len; ) {
            if (
                erc721 == registeredERC721Ids[i].erc721 &&
                id == registeredERC721Ids[i].id
            ) {
                // If not last elem in array, copy last elem to this index.
                if (i < len - 1) {
                    registeredERC721Ids[i] = registeredERC721Ids[len - 1];
                }
                registeredERC721Ids.pop();

                emit ERC721IdDeregistered(erc721, id);
                break;
            }

            unchecked { ++i; }
        }
    }

    /// @inheritdoc IReserve
    function updateOracleForERC20(address erc20, address oracle)
        external
        onlyOwner
        isRegisteredERC20(erc20)
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

    /// @inheritdoc IReserve
    function updateOracleForERC721Id(
        address erc721,
        uint id,
        address oracle
    ) external onlyOwner isRegisteredERC721Id(erc721, id) {
        // Cache old oracle.
        address oldOracle = oraclePerERC721Id[erc721][id];

        // Do nothing if new oracle is same as old oracle.
        if (oldOracle == oracle) {
            return;
        }

        // Check oracle's validity.
        require(_oracleIsValid(oracle));

        // Update erc721Id's oracle and notify off-chain services.
        oraclePerERC721Id[erc721][id] = oracle;
        emit SetERC721IdOracle(erc721, id, oldOracle, oracle);
    }

    //----------------------------------
    // Bonding & Redeeming Management

    /// @inheritdoc IReserve
    function listERC20AsBondable(address erc20)
        public
        onlyOwner
        isRegisteredERC20(erc20)
    {
        isERC20Bondable[erc20] = true;
        emit ERC20ListedAsBondable(erc20);
    }

    /// @inheritdoc IReserve
    function delistERC20AsBondable(address erc20)
        external
        onlyOwner
        isRegisteredERC20(erc20)
    {
        isERC20Bondable[erc20] = false;
        emit ERC20DelistedAsBondable(erc20);
    }

    /// @inheritdoc IReserve
    function listERC721IdAsBondable(address erc721, uint id)
        public
        onlyOwner
        isRegisteredERC721Id(erc721, id)
    {
        isERC721IdBondable[erc721][id] = true;
        emit ERC721IdListedAsBondable(erc721, id);
    }

    /// @inheritdoc IReserve
    function delistERC721IdAsBondable(address erc721, uint id)
        external
        onlyOwner
        isRegisteredERC721Id(erc721, id)
    {
        isERC721IdBondable[erc721][id] = false;
        emit ERC721IdDelistedAsBondable(erc721, id);
    }

    /// @inheritdoc IReserve
    function listERC20AsRedeemable(address erc20)
        public
        onlyOwner
        isRegisteredERC20(erc20)
    {
        isERC20Redeemable[erc20] = true;
        emit ERC20ListedAsRedeemable(erc20);
    }

    /// @inheritdoc IReserve
    function delistERC20AsRedeemable(address erc20)
        external
        onlyOwner
        isRegisteredERC20(erc20)
    {
        isERC20Redeemable[erc20] = false;
        emit ERC20DelistedAsRedeemable(erc20);
    }

    /// @inheritdoc IReserve
    function listERC721IdAsRedeemable(address erc721, uint id)
        public
        onlyOwner
        isRegisteredERC721Id(erc721, id)
    {
        isERC721IdRedeemable[erc721][id] = true;
        emit ERC721IdListedAsRedeemable(erc721, id);
    }

    /// @inheritdoc IReserve
    function delistERC721IdAsRedeemable(address erc721, uint id)
        external
        onlyOwner
        isRegisteredERC721Id(erc721, id)
    {
        isERC721IdRedeemable[erc721][id] = false;
        emit ERC721IdDelistedAsRedeemable(erc721, id);
    }

    /// @inheritdoc IReserve
    function setERC20BondingLimit(address erc20, uint limit)
        public
        onlyOwner
    {
        uint oldLimit = bondingLimitPerERC20[erc20];

        if (limit != oldLimit) {
            emit SetERC20BondingLimit(erc20, oldLimit, limit);
            bondingLimitPerERC20[erc20] = limit;
        }
    }

    /// @inheritdoc IReserve
    function setERC20RedeemLimit(address erc20, uint limit) public onlyOwner {
        uint oldLimit = redeemLimitPerERC20[erc20];

        if (limit != oldLimit) {
            emit SetERC20RedeemLimit(erc20, oldLimit, limit);
            redeemLimitPerERC20[erc20] = limit;
        }
    }

    //----------------------------------
    // Discount Management

    /// @inheritdoc IReserve
    function setBondingDiscountForERC20(address erc20, uint discount)
        public
        onlyOwner
    {
        uint oldDiscount = bondingDiscountPerERC20[erc20];

        if (discount != oldDiscount) {
            emit SetERC20BondingDiscount(erc20, oldDiscount, discount);
            bondingDiscountPerERC20[erc20] = discount;
        }
    }

    /// @inheritdoc IReserve
    function setBondingDiscountForERC721Id(
        address erc721,
        uint id,
        uint discount
    ) public onlyOwner {
        uint oldDiscount = bondingDiscountPerERC721Id[erc721][id];

        if (discount != oldDiscount) {
            emit SetERC721IdBondingDiscount(erc721, id, oldDiscount, discount);
            bondingDiscountPerERC721Id[erc721][id] = discount;
        }
    }

    //----------------------------------
    // TimeLock Management

    /// @inheritdoc IReserve
    function setTimeLockVault(address timeLockVault_) external onlyOwner {
        if (timeLockVault != timeLockVault_) {
            // Check new time lock vault's authentication system.
            require(ITimeLockVault(timeLockVault_).isLocker(address(this)));

            // Remove old TimeLock vault's approval.
            _token.approve(timeLockVault, 0);

            // Give new TimeLock vault infinite approval.
            _token.approve(timeLockVault_, type(uint).max);

            emit SetTimeLockVault(timeLockVault, timeLockVault_);
            timeLockVault = timeLockVault_;
        }
    }

    /// @inheritdoc IReserve
    function setBondingTimeLockForERC20(address erc20, uint timeLockDuration)
        public
        onlyOwner
    {
        uint oldTimeLockDuration = bondingTimeLockDurationPerERC20[erc20];

        if (timeLockDuration != oldTimeLockDuration) {
            emit SetERC20BondingTimeLock(
                erc20,
                oldTimeLockDuration,
                timeLockDuration
            );
            bondingTimeLockDurationPerERC20[erc20] = timeLockDuration;
        }
    }

    /// @inheritdoc IReserve
    function setBondingTimeLockForERC721Id(
        address erc721,
        uint id,
        uint timeLockDuration
    ) public onlyOwner {
        uint oldTimeLockDuration = bondingTimeLockDurationPerERC721Id[erc721][id];

        if (timeLockDuration != oldTimeLockDuration) {
            emit SetERC721IdBondingTimeLock(
                erc721,
                id,
                oldTimeLockDuration,
                timeLockDuration
            );
            bondingTimeLockDurationPerERC721Id[erc721][id] = timeLockDuration;
        }
    }

    //----------------------------------
    // Bundle Functions

    /// @inheritdoc IReserve
    function setupAndListERC20Bond(
        address erc20, 
        uint limit, 
        uint discount, 
        uint timeLockDuration
    ) external onlyOwner {
        // List ERC20 as bondable if it isn't already
        if(!isERC20Bondable[erc20]) {
            listERC20AsBondable(erc20);
        }

        // Set the ERC20's limit if it isn't already
        if(bondingLimitPerERC20[erc20] != limit) {
            setERC20BondingLimit(erc20, limit);
        }

        // Set the ERC20's discount if it isn't already
        if(bondingDiscountPerERC20[erc20] != discount) {
            setBondingDiscountForERC20(erc20, discount);
        }

        // Set the ERC20's TimeLock duration if it isn't already
        if(bondingTimeLockDurationPerERC20[erc20] != timeLockDuration) {
            setBondingTimeLockForERC20(erc20, timeLockDuration);
        }
    }

    /// @inheritdoc IReserve
     function setupAndListERC20Redemption(
        address erc20, 
        uint limit
    ) external onlyOwner {
        // List ERC20 as redeemable if it isn't already
        if(!isERC20Redeemable[erc20]) {
            listERC20AsRedeemable(erc20);
        }

        // Set the ERC20's limit if it isn't already
        if(redeemLimitPerERC20[erc20] != limit) {
            setERC20RedeemLimit(erc20, limit);
        }
    }

    /// @inheritdoc IReserve
    function setupAndListERC721IdBond(
        address erc721, 
        uint id,
        uint discount, 
        uint timeLockDuration
    ) external onlyOwner {
        // List ERC721Id as bondable if it isn't already
        if(!isERC721IdBondable[erc721][id]) {
            listERC721IdAsBondable(erc721, id);
        }

        // Set the ERC721Id's discount if it isn't already
        if(bondingDiscountPerERC721Id[erc721][id] != discount) {
            setBondingDiscountForERC721Id(erc721, id, discount);
        }

        // Set the ERC721Id's TimeLock duration if it isn't already
        if(bondingTimeLockDurationPerERC721Id[erc721][id] != timeLockDuration) {
            setBondingTimeLockForERC721Id(erc721, id, timeLockDuration);
        }
    }

    /// @inheritdoc IReserve
    function setupAndListERC721IdRedemption(
        address erc721, 
        uint id
    ) external onlyOwner {
        // List ERC721Id as redeemable if it isn't already
        if(!isERC721IdRedeemable[erc721][id]) {
            listERC721IdAsRedeemable(erc721, id);
        }
    }

    //----------------------------------
    // Reserve Management

    /// @inheritdoc IReserve
    function setMinBacking(uint minBacking_) external onlyOwner {
        require(minBacking_ != 0);
        // Note that it is allowed to set minBacking higher than current backing.

        if (minBacking != minBacking_) {
            emit SetMinBacking(minBacking, minBacking_);
            minBacking = minBacking_;
        }
    }

    /// @inheritdoc IReserve
    function withdrawERC20(
        address erc20,
        address recipient,
        uint amount
    )
        external
        validAmount(amount)
        validRecipient(recipient)
        onlyOwner
        onBeforeUpdateBacking(true)
    {
        // Make sure that erc20's code is non-empty.
        // Note that solmate's safeTransferLib does not include this check.
        require(erc20.code.length != 0);

        // Transfer erc20 tokens to recipient.
        // Fails if balance is not sufficient.
        ERC20(erc20).safeTransfer(recipient, amount);

        // Notify off-chain services.
        emit WithdrewERC20(erc20, recipient, amount);
    }

    /// @inheritdoc IReserve
    function withdrawERC721Id(
        address erc721,
        uint id,
        address recipient
    ) external validRecipient(recipient) onlyOwner onBeforeUpdateBacking(true) {
        ERC721(erc721).safeTransferFrom(address(this), recipient, id);
        
        // Notify off-chain services.
        emit WithdrewERC721Id(erc721, id, recipient);
    }

    /// @inheritdoc IReserve
    function incurDebt(uint amount)
        external
        onlyOwner
        onBeforeUpdateBacking(true)
    {
        // Mint tokens, i.e. create debt.
        _token.mint(msg.sender, amount);

        // Notify off-chain services.
        emit DebtIncurred(amount);
    }

    /// @inheritdoc IReserve
    function payDebt(uint amount)
        external
        onlyOwner
        // Note that min backing is not enforced. Otherwise it would be
        // impossible to partially repay debt after valuation contracted to
        // below min backing requirement.
        onBeforeUpdateBacking(false)
    {
        // Burn tokens, i.e. repay debt.
        _token.burn(msg.sender, amount);

        // Notify off-chain services.
        emit DebtPaid(amount);
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
        // Note that if an ERC20 is bondable, it is also registered.
        // isRegisteredERC20(erc20)
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

        // Notify off-chain services.
        emit BondedERC20(erc20, erc20Amount, amount);
    }

    function _bondERC721Id(
        address erc721,
        uint id,
        address from,
        address to
    )
        private
        // Note that if an ERC721Id is bondable, it is also registered.
        // isRegisteredERC721Id(erc721, id)
        isBondableERC721Id(erc721, id)
        validRecipient(to)
        onBeforeUpdateBacking(true)
    {
        // Fetch erc721Id.
        ERC721(erc721).safeTransferFrom(from, address(this), id);

        // Compute amount of tokens to mint.
        uint amount = _computeMintAmountGivenERC721Id(erc721, id);

        // Mint tokens.
        _commitTokenMintGivenERC721Id(erc721, id, to, amount);

        // Notify off-chain services.
        emit BondedERC721(erc721, id, amount);
    }

    //----------------------------------
    // Redeem Functions

    function _redeemERC20(
        address erc20,
        address from,
        address to,
        uint tokenAmount
    )
        private
        // Note that if an ERC20 is redeemable, it is also registered.
        // isRegisteredERC20(erc20)
        isRedeemableERC20(erc20)
        validRecipient(to)
        validAmount(tokenAmount)
        onBeforeUpdateBacking(true)
    {
        // Calculate valuation of tokens to burn.
        uint tokenValue = (tokenAmount * _priceOfToken()) / 1e18;

        // Calculate the amount of erc20 tokens to withdraw.
        uint erc20AmountWad = (tokenValue * 1e18) / _priceOfERC20(erc20);

        // Convert erc20 amount from wad format.
        uint erc20Amount = Wad.convertFromWad(erc20, erc20AmountWad);

        // Revert if balance not sufficient.
        uint balance = ERC20(erc20).balanceOf(address(this));
        if (balance < erc20Amount) {
            revert Reserve__ERC20BalanceNotSufficient();
        }

        // Revert if redeem limit exceeded.
        uint limit = redeemLimitPerERC20[erc20];
        if (balance - erc20Amount < limit) {
            revert Reserve__ERC20RedeemLimitExceeded();
        }

        // Notify off-chain services.
        emit RedeemedERC20(erc20, erc20Amount, tokenAmount);

        // Withdraw erc20s and burn tokens.
        ERC20(erc20).safeTransfer(to, erc20Amount);
        _token.burn(from, tokenAmount);
    }

    function _redeemERC721Id(
        address erc721,
        uint id,
        address from,
        address to
    )
        private
        // Note that if an ERC721Id is redeemable, it is also registered.
        // isRegisteredERC721Id(erc721, id)
        isRedeemableERC721Id(erc721, id)
        validRecipient(to)
        onBeforeUpdateBacking(true)
    {
        // Query erc721Id's price oracle.
        uint priceWad = _priceOfERC721Id(erc721, id);

        // Calculate the amount of tokens to burn.
        uint tokenAmount = (priceWad / _priceOfToken()) * 1e18;

        // Notify off-chain services.
        emit RedeemedERC721Id(erc721, id, tokenAmount);

        // Burn tokens and withdraw ERC721Id.
        // Note that the ERC721 transfer triggers a callback if the recipient
        // is a contract. However, reentry should not be a problem as the
        // transfer is the last operation executed.
        _token.burn(from, tokenAmount);
        ERC721(erc721).safeTransferFrom(address(this), to, id);
    }

    function _computeMintAmountGivenERC20(address erc20, uint amount)
        private
        view
        returns (uint)
    {
        // Convert erc20 amount to wad format.
        uint amountWad = Wad.convertToWad(erc20, amount);

        // Calculate the total value of erc20 tokens.
        uint valuationWad = (amountWad * _priceOfERC20(erc20)) / 1e18;

        // Calculate the number of tokens to mint (no discount applied yet).
        uint toMint = (valuationWad * 1e18) / _priceOfToken();

        // Apply discount.
        toMint = _applyBondingDiscountForERC20(erc20, toMint);

        return toMint;
    }

    function _computeMintAmountGivenERC721Id(address erc721, uint id)
        private
        view
        returns (uint)
    {
        // Note that erc721Ids price equals it's bonding valuation because the
        // amount of tokens bonded is always 1.

        // Calculate the number of tokens to mint (no discount applied yet).
        uint toMint = (_priceOfERC721Id(erc721, id) * 1e18) / _priceOfToken();

        // Apply discount.
        toMint = _applyBondingDiscountForERC721Id(erc721, id, toMint);

        return toMint;
    }

    //----------------------------------
    // Reserve Functions

    function _reserveStatus()
        private
        view
        returns (
            uint,
            uint,
            uint
        )
    {
        uint reserveValuation = _reserveValuation();
        uint supplyValuation = _supplyValuation();

        uint backing =
            supplyValuation == 0
                ? BPS
                : (reserveValuation * BPS) / supplyValuation;

        return (reserveValuation, supplyValuation, backing);
    }

    function _supplyValuation() private view returns (uint) {
        return (_token.totalSupply() * _priceOfToken()) / 1e18;
    }

    function _reserveValuation() private view returns (uint) {
        return _reserveERC20sValuation() + _reserveERC721IdsValuation();
    }

    function _reserveERC20sValuation() private view returns (uint) {
        // The total valuation of registered ERC20 assets in the reserve.
        uint totalWad;

        // Declare variables outside of loop to save gas.
        address erc20;
        uint balanceWad;

        // Calculate the total valuation of registered ERC20 assets in the
        // reserve.
        uint len = registeredERC20s.length;
        for (uint i; i < len; ) {
            erc20 = registeredERC20s[i];

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

            // Add asset's valuation to the total valuation.
            totalWad += (balanceWad * _priceOfERC20(erc20)) / 1e18;

            unchecked { ++i; }
        }

        return totalWad;
    }

    function _reserveERC721IdsValuation() private view returns (uint) {
        // The total valuation of registered ERC721 assets in the reserve.
        uint totalWad;

        // Declare variables outside of loop to save gas.
        address erc721;
        uint id;

        // Calculate the total valuation of registered ERC721 assets in the
        // reserve.
        uint len = registeredERC721Ids.length;
        for (uint i; i < len; ) {
            erc721 = registeredERC721Ids[i].erc721;
            id = registeredERC721Ids[i].id;

            // Continue/Break if reserve is not the owner of that erc721Id.
            if (ERC721(erc721).ownerOf(id) != address(this)) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked { ++i; }
                    continue;
                }
            }

            // Add erc721Id's price to the total valuation.
            totalWad += _priceOfERC721Id(erc721, id);

            unchecked { ++i; }
        }

        return totalWad;
    }

    //----------------------------------
    // Oracle Functions

    function _oracleIsValid(address oracle) private view returns (bool) {
        bool valid;
        uint price;
        (price, valid) = IOracle(oracle).getData();

        return valid && price != 0;
    }

    function _priceOfToken() private view returns (uint) {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(tokenOracle).getData();

        if (!valid || price == 0) {
            // Revert if oracle is invalid or price is zero.
            revert Reserve__InvalidOracle();
        }

        return price;
    }

    function _priceOfERC20(address erc20) private view returns (uint) {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(oraclePerERC20[erc20]).getData();

        if (!valid || price == 0) {
            // Revert if oracle is invalid or price is zero.
            revert Reserve__InvalidOracle();
        }

        return price;
    }

    function _priceOfERC721Id(address erc721, uint id)
        private
        view
        returns (uint)
    {
        // Note that the price is returned in 18 decimal precision.
        uint price;
        bool valid;
        (price, valid) = IOracle(oraclePerERC721Id[erc721][id]).getData();

        if (!valid || price == 0) {
            // Revert if oracle is invalid or price is zero.
            revert Reserve__InvalidOracle();
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
        uint timeLockDuration = bondingTimeLockDurationPerERC20[erc20];

        if(timeLockDuration != 0 && timeLockVault != address(0)) {
            // Vest token via TimeLock vault.
            _token.mint(address(this), amount);

            // Note that the tokens are fetched from address(this) to the
            // TimeLock vault.
            ITimeLockVault(timeLockVault).lock(to, address(_token), amount, timeLockDuration);
        } else {
            // No TimeLock, mint tokens directly to user.
            _token.mint(to, amount);
        }
    }

    function _commitTokenMintGivenERC721Id(
        address erc721,
        uint id,
        address to,
        uint amount
    ) private {
        uint timeLockDuration = bondingTimeLockDurationPerERC721Id[erc721][id];

        if(timeLockDuration != 0 && timeLockVault != address(0)) {
            // Vest token via TimeLock vault.
            _token.mint(address(this), amount);

            // Note that the tokens are fetched from address(this) to the
            // TimeLock vault.
            ITimeLockVault(timeLockVault).lock(to, address(_token), amount, timeLockDuration);
        } else {
            // No TimeLock, mint tokens directly to user.
            _token.mint(to, amount);
        }
    }

    //----------------------------------
    // Discount Functions

    function _applyBondingDiscountForERC20(address erc20, uint amount)
        private
        view
        returns (uint)
    {
        uint discount = bondingDiscountPerERC20[erc20];

        return discount == 0
            ? amount
            : amount + (amount * discount) / BPS;
    }

    function _applyBondingDiscountForERC721Id(
        address erc721,
        uint id,
        uint amount
    ) private view returns (uint) {
        uint discount = bondingDiscountPerERC721Id[erc721][id];

        return discount == 0
            ? amount
            : amount + (amount * discount) / BPS;
    }
}
