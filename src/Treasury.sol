// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

// External Interfaces.
import { IERC20Metadata } from "./interfaces/_external/IERC20Metadata.sol";
import { IERC721Receiver } from "./interfaces/_external/IERC721Receiver.sol";

// External Contracts.
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { TSOwnable } from "solrocket/TSOwnable.sol";

// External Libraries.
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

// Internal Interfaces.
import { IOracle } from "./interfaces/IOracle.sol";

// Internal Contracts.
import { ElasticReceiptToken } from "./ElasticReceiptToken.sol";

// Internal Libraries.
import { Wad } from "./lib/Wad.sol";

/**
 * @title Treasury
 *
 * @dev A treasury in which the owner can bond and redeem assets.
 *      The treasury token (KTT) is continously synced to the treasury's total
 *      value in USD of assets held. This is made possible by inheriting from
 *      the ElasticReceiptToken.
 *
 *      Naming Conventions for non-public variables:
 *      - If a variable does NOT include the term `wad` the decimal precision
 *        is either unknown or unequal to 18.
 *      - If a variable does include the term `wad` the decimal precision is
 *        18.
 *
 * @author byterocket
 */
contract Treasury is ElasticReceiptToken, TSOwnable, IERC721Receiver {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Function is only callable for bondable erc20's.
    /// @param erc20 The address of the erc20 token.
    error Treasury__ERC20IsNotBondable(address erc20);

    /// @notice Function is only callable for bondable erc721Id's.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    error Treasury__ERC721IdIsNotBondable(address erc721, uint id);

    /// @notice Function is only callable for redeemable erc20's.
    /// @param erc20 The address of the erc20 token.
    error Treasury__ERC20IsNotRedeemable(address erc20);

    /// @notice Function is only callable for redeemable erc721Id's.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    error Treasury__ERC721IdIsNotRedeemable(address erc721, uint id);

    /// @notice Function is only callable for registered erc20's.
    /// @param erc20 The address of the erc20 token.
    error Treasury__ERC20IsNotRegistered(address erc20);

    /// @notice Function is only callable for registered erc721Id's.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    error Treasury__ERC721IdIsNotRegistered(address erc721, uint id);

    /// @notice Functionality is limited due to stale price delivered by oracle.
    /// @param erc20 The address of the erc20 token.
    /// @param oracle The address of the asset's oracle.
    error Treasury__StaleERC20PriceDeliveredByOracle(
        address erc20,
        address oracle
    );

    /// @notice Functionality is limited due to stale price delivered by oracle.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    /// @param oracle The address of the asset's oracle.
    error Treasury__StaleERC721IdPriceDeliveredByOracle(
        address erc721,
        uint id,
        address oracle
    );

    //--------------------------------------------------------------------------
    // Events

    //----------------------------------
    // Price Events

    /// @notice Event emitted when an erc20's cached price is updated.
    /// @param erc20 The address of the erc20 token.
    /// @param oracle The address of the oracle.
    /// @param oldPrice The cached price before the update.
    /// @param newPrice The cached price after the update.
    event ERC20PriceUpdated(
        address indexed erc20,
        address indexed oracle,
        uint oldPrice,
        uint newPrice
    );

    /// @notice Event emitted when an erc721Id's cached price is updated.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    /// @param oracle The address of the oracle.
    /// @param oldPrice The cached price before the update.
    /// @param newPrice The cached price after the update.
    event ERC721IdPriceUpdated(
        address indexed erc721,
        uint indexed id,
        address indexed oracle,
        uint oldPrice,
        uint newPrice
    );

    //----------------------------------
    // onlyOwner Events

    //--------------
    // Asset and Oracle Management

    /// @notice Event emitted when an erc20 is registered
    /// @param erc20 The address of the erc20 token.
    /// @param oracle The address of the asset's oracle.
    event ERC20Registered(
        address indexed erc20,
        address indexed oracle,
        AssetType assetType
    );

    /// @notice Event emitted when an erc721Id is registered
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    /// @param oracle The address of the asset's oracle.
    event ERC721IdRegistered(
        address indexed erc721,
        uint indexed id,
        address indexed oracle
    );

    /// @notice Event emitted when an erc20 is unregistered.
    /// @param erc20 The address of the erc20 token.
    event ERC20Unregistered(address indexed erc20);

    /// @notice Event emitted when an erc721Id is unregistered.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    event ERC721IdUnregistered(address indexed erc721, uint indexed id);

    /// @notice Event emitted when an erc20's oracle is updated.
    /// @param erc20 The address of the erc20 token.
    /// @param oldOracle The address of the asset's old oracle.
    /// @param newOracle The address of the asset's new oracle.
    event ERC20OracleUpdated(
        address indexed erc20,
        address oldOracle,
        address newOracle
    );

    /// @notice Event emitted when an erc721Id's oracle is updated.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    /// @param oldOracle The address of the asset's old oracle.
    /// @param newOracle The address of the asset's new oracle.
    event ERC721IdOracleUpdated(
        address indexed erc721,
        uint indexed id,
        address oldOracle,
        address newOracle
    );

    //--------------
    // Un/Bonding Management

    /// @notice Event emitted when an erc20 is listed as bondable.
    /// @param erc20 The address of the erc20 token.
    event ERC20ListedAsBondable(address indexed erc20);

    /// @notice Event emitted when an erc721 is listed as bondable.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    event ERC721IdListedAsBondable(address indexed erc721, uint indexed id);

    /// @notice Event emitted when an asset is listed as redeemable.
    /// @param erc20 The address of the erc20 token.
    event ERC20ListedAsRedeemable(address indexed erc20);

    /// @notice Event emitted when an asset is listed as redeemable.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    event ERC721IdListedAsRedeemable(address indexed erc721, uint indexed id);

    /// @notice Event emitted when an asset is delisted as bondable.
    /// @param erc20 The address of the erc20 token.
    event ERC20DelistedAsBondable(address indexed erc20);

    /// @notice Event emitted when an asset is delisted as bondable.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    event ERC721IdDelistedAsBondable(address indexed erc721, uint indexed id);

    /// @notice Event emitted when an asset is delisted as redeemable.
    /// @param erc20 The address of the erc20 token.
    event ERC20DelistedAsRedeemable(address indexed erc20);

    /// @notice Event emitted when an asset is delisted as redeemable.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    event ERC721IdDelistedAsRedeemable(address indexed erc721, uint indexed id);

    //----------------------------------
    // User Events

    /// @notice Event emitted when erc20's are bonded.
    /// @param who The address of the user.
    /// @param erc20 The address of the erc20 token.
    /// @param kttsMinted The number of KTTs minted.
    event ERC20sBonded(
        address indexed who,
        address indexed erc20,
        uint kttsMinted
    );

    /// @notice Event emitted when erc721Id's are bonded.
    /// @param who The address of the user.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    /// @param kttsMinted The number of KTTs minted.
    event ERC721IdsBonded(
        address indexed who,
        address indexed erc721,
        uint indexed id,
        uint kttsMinted
    );

    /// @notice Event emitted when erc20's are redeemed.
    /// @param who The address of the user.
    /// @param erc20 The address of the erc20 token.
    /// @param kttsBurned The number of KTTs burned.
    event ERC20sRedeemed(
        address indexed who,
        address indexed erc20,
        uint kttsBurned
    );

    /// @notice Event emitted when erc721Id's are redeemed.
    /// @param who The address of the user.
    /// @param erc721 The address of the erc721 token.
    /// @param id The id of the corresponding NFT.
    /// @param kttsBurned The number of KTTs burned.
    event ERC721IdsRedeemed(
        address indexed who,
        address indexed erc721,
        uint indexed id,
        uint kttsBurned
    );

    //--------------------------------------------------------------------------
    // Modifiers

    /// @notice Modifier to guarantee function is only callable with registered
    ///         ERC20's.
    modifier isRegisteredERC20(address erc20) {
        if (oraclePerERC20[erc20] == address(0)) {
            revert Treasury__ERC20IsNotRegistered(erc20);
        }
        _;
    }

    /// @notice Modifier to guarantee function is only callable with registered
    ///         ERC721Id's.
    modifier isRegisteredERC721Id(address erc721, uint id) {
        if (oraclePerERC721Id[erc721][id] == address(0)) {
            revert Treasury__ERC721IdIsNotRegistered(erc721, id);
        }
        _;
    }

    /// @notice Modifier to guarantee function is only callable with bondable
    ///         ERC20's.
    modifier isBondableERC20(address erc20) {
        if (!isERC20Bondable[erc20]) {
            revert Treasury__ERC20IsNotBondable(erc20);
        }
        _;
    }

    /// @notice Modifier to guarantee function is only callable with bondable
    ///         ERC721Id's.
    modifier isBondableERC721Id(address erc721, uint id) {
        if (!isERC721IdBondable[erc721][id]) {
            revert Treasury__ERC721IdIsNotBondable(erc721, id);
        }
        _;
    }

    /// @notice Modifier to guarantee function is only callable with redeemable
    ///         ERC20's.
    modifier isRedeemableERC20(address erc20) {
        if (!isERC20Redeemable[erc20]) {
            revert Treasury__ERC20IsNotRedeemable(erc20);
        }
        _;
    }

    /// @notice Modifier to guarantee function is only callable with redeemable
    ///         assets.
    modifier isRedeemableERC721Id(address erc721, uint id) {
        if (!isERC721IdRedeemable[erc721][id]) {
            revert Treasury__ERC721IdIsNotRedeemable(erc721, id);
        }
        _;
    }

    // TODO Bonding limit?

    //--------------------------------------------------------------------------
    // Storage

    /// @notice The erc20's registered by the treasury, i.e. the erc20's taken
    ///         into account for the treasury's valuation.
    /// @dev Each registered erc20 always has to have a corresponding oracle
    ///      in the oraclePerERC20 mapping!
    /// @dev Changeable by owner.
    /// @dev Addresses are of type ERC20.
    address[] public registeredERC20s;

    /// @notice The erc721Id's registered by the treasury, i.e. the erc721Id's
    ///         taken into account for the treasury's valuation.
    /// @dev Each registered asset always has to have a corresponding oracle
    ///      in the oraclePerERC721Id mapping!
    /// @dev Changeable by owner.
    /// @dev ERC721Ids are of type ERC721Id, containing the address and id.
    ERC721Id[] public registeredERC721Ids;

    /// @notice The type of each ERC20-based asset registered by the treasury
    /// @dev    Changeable by owner
    /// @dev    Address in registeredERC20s => Asset Type (enum)
    mapping(address => AssetType) public assetTypeOfERC20;

    /// @notice The mapping of oracles providing the price for an erc20.
    /// @dev Changeable by owner.
    /// @dev Address in registeredERC20s => address of type IOracle.
    mapping(address => address) public oraclePerERC20;

    /// @notice The mapping of oracles providing the price for an erc721Id.
    /// @dev Changeable by owner.
    /// @dev address in registeredERC721Ids => uint id in
    //       registeredERC721Ids => address of type IOracle.
    mapping(address => mapping(uint => address)) public oraclePerERC721Id;

    /// @notice Mapping of bondable erc20's.
    /// @dev Changeable by owner.
    mapping(address => bool) public isERC20Bondable;

    /// @notice Mapping of bondable erc721Id's.
    /// @dev Changeable by owner.
    mapping(address => mapping(uint => bool)) public isERC721IdBondable;

    /// @notice Mapping of redeemable erc20's.
    /// @dev Changeable by owner.
    mapping(address => bool) public isERC20Redeemable;

    /// @notice Mapping of redeemable erc721Id's.
    /// @dev Changeable by owner.
    mapping(address => mapping(uint => bool)) public isERC721IdRedeemable;

    /// @notice Each ERC20-based asset is of a certain type, either it is a regular
    ///         token, a stable token or an ecological asset (e.g. fractionalized
    ///         GeoNFTs).
    enum AssetType {
        Default,
        Stable,
        Ecological
    }

    /// @notice For some actions, an ERC721Id needs to be stored into a one object
    //          instead of in separate variables, e.g. in the registeredERC721Ids-array
    struct ERC721Id {
        /// @dev The ERC721 contract address.
        address erc721;
        /// @dev The token's id.
        uint id;
    }

    //--------------------------------------------------------------------------
    // Constructor

    constructor()
        ElasticReceiptToken("Kolektivo Treasury Token", "KTT", uint8(18))
    {
        // NO-OP
    }

    //--------------------------------------------------------------------------
    // View Functions

    /// @notice Returns the array of all registered erc20 assets
    function allRegisteredERC20s() external view returns (address[] memory) {
        return registeredERC20s;
    }

    /// @notice Returns the array of all registered erc721Id assets
    function allRegisteredERC721Ids()
        external
        view
        returns (ERC721Id[] memory)
    {
        return registeredERC721Ids;
    }

    //--------------------------------------------------------------------------
    // Bond & Redeem Functions

    /// @notice Bonds an amount of one erc20 in exchange for an amount of KTTs.
    /// @dev Only callable if address is whitelisted.
    /// @dev Only callable for bondable assets.
    /// @param erc20 The erc20 token to bond.
    /// @param amount The amount of erc20's to bond.
    function bondERC20(address erc20, uint amount)
        external
        // Note that if an erc20 is bondable, it is also supported.
        // isRegistered(erc20)
        isBondableERC20(erc20)
        validAmount(amount)
        onlyOwner
    {
        // Convert amount to wad.
        uint amountWad = Wad.convertToWad(erc20, amount);

        // Calculate the amount of KTTs to mint.
        // Note that 1 KTT equals 1 USD worth of assets in the treasury.
        uint mintWad = (amountWad * _queryERC20Price(erc20)) / 1e18;

        // Mint the KTTs to msg.sender and fetch the asset from msg.sender.
        super._mint(msg.sender, mintWad);
        ERC20(erc20).safeTransferFrom(msg.sender, address(this), amount);

        // Notify off-chain services.
        emit ERC20sBonded(msg.sender, erc20, mintWad);
    }

    /// @notice Bonds an erc721Id in exchange for an amount of KTTs.
    /// @dev Only callable if address is whitelisted.
    /// @dev Only callable for bondable assets.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    function bondERC721Id(address erc721, uint id)
        external
        // Note that if an erc721Id is bondable, it is also supported.
        // isRegistered(erc721, id)
        isBondableERC721Id(erc721, id)
        onlyOwner
    {
        // Retrieve the price of the ERC721Id, which corresponds to it's
        // value and thus the amount of KTTs to mint.
        // Note that 1 KTT equals 1 USD worth of assets in the treasury.
        uint mintWad = _queryERC721IdPrice(erc721, id);

        // Mint the KTTs to msg.sender and fetch the asset from msg.sender.
        super._mint(msg.sender, mintWad);
        ERC721(erc721).safeTransferFrom(msg.sender, address(this), id);

        // Notify off-chain services.
        emit ERC721IdsBonded(msg.sender, erc721, id, mintWad);
    }

    /// @notice Redeems an amount of KTTs in exchange for an amount of an
    ///         erc20.
    /// @dev Only callable if address is whitelisted.
    /// @dev Only callable for redeemable assets.
    /// @param erc20 The erc20 token to unbond.
    /// @param kttWad The amount of KTT tokens to burn.
    function redeemERC20(address erc20, uint kttWad)
        external
        // Note that if an asset is unbondable, it is also supported.
        // isRegistered(asset)
        isRedeemableERC20(erc20)
        validAmount(kttWad)
        onlyOwner
    {
        // Burn KTTs from msg.sender.
        // Note to update the KTT amount which could have changed due to
        // rebasing.
        kttWad = super._burn(msg.sender, kttWad);

        // Calculate the amount of erc20's to withdraw for burned amount of KTTs.
        // Note that 1 KTT equals 1 USD worth of erc20's in the treasury.
        uint withdrawableWad = (kttWad * 1e18) / _queryERC20Price(erc20);

        // Adjust to decimal precision of the erc20.
        uint withdrawable = Wad.convertFromWad(erc20, withdrawableWad);

        // Send the erc20's to msg.sender.
        ERC20(erc20).safeTransfer(msg.sender, withdrawable);

        // Notify off-chain services.
        emit ERC20sRedeemed(msg.sender, erc20, kttWad);
    }

    /// @notice Redeems an amount of KTTs in exchange for an amount of one
    ///         ERC721Id.
    /// @dev Only callable if address is whitelisted.
    /// @dev Only callable for redeemable assets.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    function redeemERC721Id(address erc721, uint id)
        external
        // Note that if an asset is unbondable, it is also supported.
        // isRegistered(erc721, id)
        isRedeemableERC721Id(erc721, id)
        onlyOwner
    {
        uint kttWad = _queryERC721IdPrice(erc721, id);

        // Burn KTTs from msg.sender.
        // Note to update the KTT amount which could have changed due to
        // rebasing.
        kttWad = super._burn(msg.sender, kttWad);

        // Send the erc20's to msg.sender.
        ERC721(erc721).safeTransferFrom(address(this), msg.sender, id);

        // Notify off-chain services.
        emit ERC721IdsRedeemed(msg.sender, erc721, id, kttWad);
    }

    //--------------------------------------------------------------------------
    // Public View Functions

    /// @notice Returns the total valuation of assets, denominated in USD, held
    ///         in the treasury.
    /// @return The USD value of assets held in the treasury.
    function totalValuation() external view returns (uint) {
        return _supplyTarget();
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
    // ElasticReceiptToken Functions

    /// @dev Computes the total valuation of assets held in the treasury and
    ///      uses that value as KTT's supply target.
    /// @dev Has to be in same decimal precision as token, i.e. 18.
    function _supplyTarget()
        internal
        view
        override(ElasticReceiptToken)
        returns (uint)
    {
        // Return the total valuation of assets in the treasury.
        return _erc20Value() + _erc721IdValue();
    }

    function _erc20Value() internal view returns (uint) {
        // Declare variables outside of loop to save gas.
        address erc20;
        uint erc20Balance;
        uint erc20BalanceWad;

        // The total valuation of erc20's in the treasury.
        uint totalWad;

        uint len = registeredERC20s.length;
        for (uint i; i < len; ) {
            erc20 = registeredERC20s[i];
            erc20Balance = ERC20(erc20).balanceOf(address(this));

            // Continue/Break early if there is no erc20 balance.
            if (erc20Balance == 0) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            }

            // Multiply the erc20's price with the erc20's balance and add the
            // erc20's valuation to the total valuation.
            erc20BalanceWad = Wad.convertToWad(erc20, erc20Balance);
            totalWad += (erc20BalanceWad * _queryERC20Price(erc20)) / 1e18;

            unchecked {
                ++i;
            }
        }

        // Return the total valuation of erc20's in the treasury.
        return totalWad;
    }

    function _erc721IdValue() internal view returns (uint) {
        // Declare variables outside of loop to save gas.
        address erc721;
        uint id;

        // The total valuation of erc721Ids's in the treasury.
        uint totalWad;

        uint len = registeredERC721Ids.length;
        for (uint i; i < len; ) {
            erc721 = registeredERC721Ids[i].erc721;
            id = registeredERC721Ids[i].id;

            // Continue/Break early if the nft is not owned by
            // the treasury.
            if (ERC721(erc721).ownerOf(id) != address(this)) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            }

            // Add the erc721Id's valuation to the total valuation
            totalWad += _queryERC721IdPrice(erc721, id);

            unchecked {
                ++i;
            }
        }

        // Return the total valuation of erc721Id's in the treasury.
        return totalWad;
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
        (
            success, /*returnData*/

        ) = target.call(callData);
        require(success);
    }

    //----------------------------------
    // Asset and Oracle Management

    /// @notice Withdraws some amount of given erc20 to some recipient.
    /// @dev Note that a rebase is executed after the withdrawal!
    ///      In case the erc20 was marked as supported, i.e. the erc20's
    ///      balance valuation taken into account for the total valuation
    ///      calculation, the loss in USD valuation through the withdrawal
    ///      of the erc20 amount is synched to each token holder.
    ///      While this operation is non-dilutive, it could reduce the token
    ///      balance of each holder.
    /// @dev Only callable by owner.
    /// @param erc20 The address of the erc20 token.
    /// @param recipient The recipient address.
    /// @param amount The amount of the erc20 to withdraw.
    function withdrawERC20(
        address erc20,
        address recipient,
        uint amount
    ) external validAmount(amount) validRecipient(recipient) onlyOwner {
        // @todo Add Event!
        // Make sure that asset's code is non-empty.
        // Note that solmate's safeTransferLib does not include this check.
        require(erc20.code.length != 0);

        // Transfer asset amount to recipient.
        // Fails if balance not sufficient.
        ERC20(erc20).safeTransfer(recipient, amount);

        // Initiate rebase.
        // Note that the possible loss in USD valuation is therefore synched to
        // each token holder.
        super.rebase();
    }

    /// @notice Withdraws an erc721Id to some recipient.
    /// @dev Note that a rebase is executed after the withdrawal!
    ///      In case the erc721Id was marked as supported, i.e. the erc721Id's
    ///      balance valuation taken into account for the total valuation
    ///      calculation, the loss in USD valuation through the withdrawal
    ///      of the erc721Id amount is synched to each token holder.
    ///      While this operation is non-dilutive, it could reduce the token
    ///      balance of each holder.
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    /// @param recipient The recipient address.
    function withdrawERC721Id(
        address erc721,
        uint id,
        address recipient
    ) external validRecipient(recipient) onlyOwner {
        // @todo Add Event!
        // Make sure that erc721's code is non-empty.
        // Note that solmate's safeTransferLib does not include this check.
        require(erc721.code.length != 0);

        // Transfer asset amount to recipient.
        // Fails if balance not sufficient.
        ERC721(erc721).safeTransferFrom(address(this), recipient, id);

        // Initiate rebase.
        // Note that the possible loss in USD valuation is therefore synched to
        // each token holder.
        super.rebase();
    }

    /// @notice Registers a new erc20.
    /// @dev Only callable by owner.
    /// @param erc20 The address of the erc20 token.
    /// @param oracle The address of the asset's oracle.
    /// @param assetType The type of the asset
    function registerERC20(
        address erc20,
        address oracle,
        AssetType assetType
    ) external onlyOwner {
        // Make sure that asset's code is non-empty.
        // Note that solmate's safeTransferLib does not include this check.
        require(erc20.code.length != 0);

        address oldOracle = oraclePerERC20[erc20];

        // Do nothing if asset is already registered and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert if asset is already registered but oracles differ.
        // Note that the updateAssetOracle function should be used for this.
        require(oldOracle == address(0));

        // Query oracle.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Do not accept invalid oracle response or price of zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StaleERC20PriceDeliveredByOracle(erc20, oracle);
        }

        // Revert if the asset type is invalid
        require(uint(assetType) <= 2);

        // Add asset and oracle to storage.
        registeredERC20s.push(erc20);
        oraclePerERC20[erc20] = oracle;
        assetTypeOfERC20[erc20] = assetType;

        // Notify off-chain services.
        emit ERC20Registered(erc20, oracle, assetType);
    }

    /// @notice Registers a new erc721Id.
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    /// @param oracle The address of the asset's oracle.
    function registerERC721Id(
        address erc721,
        uint id,
        address oracle
    ) external onlyOwner {
        // Make sure that asset's code is non-empty.
        // Note that solmate's safeTransferLib does not include this check.
        require(erc721.code.length != 0);

        address oldOracle = oraclePerERC721Id[erc721][id];

        // Do nothing if asset is already registered and oracles are the same.
        if (oldOracle == oracle) {
            return;
        }

        // Revert if asset is already registered but oracles differ.
        // Note that the updateAssetOracle function should be used for this.
        require(oldOracle == address(0));

        // Query oracle.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Do not accept invalid oracle response or price of zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StaleERC721IdPriceDeliveredByOracle(
                erc721,
                id,
                oracle
            );
        }

        // Add asset and oracle to storage.
        registeredERC721Ids.push(ERC721Id(erc721, id));
        oraclePerERC721Id[erc721][id] = oracle;

        // Notify off-chain services.
        emit ERC721IdRegistered(erc721, id, oracle);
    }

    /// @notice Unregisters an erc20.
    /// @dev Only callable by owner.
    /// @param erc20 The address of the erc20 token.
    function unregisterERC20(address erc20) external onlyOwner {
        // Do nothing if erc20 is already not supported.
        // Note that we do not use the isRegistered modifier to be idempotent.
        if (oraclePerERC20[erc20] == address(0)) {
            return;
        }

        // Remove erc20's oracle.
        delete oraclePerERC20[erc20];
        delete assetTypeOfERC20[erc20];

        // Remove erc20 from registeredERC20s array.
        uint len = registeredERC20s.length;
        for (uint i; i < len; ) {
            if (erc20 == registeredERC20s[i]) {
                // If not last elem in array, copy last elem to this index.
                if (i < len - 1) {
                    registeredERC20s[i] = registeredERC20s[len - 1];
                }
                registeredERC20s.pop();

                emit ERC20Unregistered(erc20);
                break;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Unregisters an erc721Id.
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    function unregisterERC721Id(address erc721, uint id) external onlyOwner {
        // Do nothing if asset is already not supported.
        // Note that we do not use the isRegistered modifier to be idempotent.
        if (oraclePerERC721Id[erc721][id] == address(0)) {
            return;
        }

        // Remove erc721Id's oracle.
        delete oraclePerERC721Id[erc721][id];

        // Remove asset from registeredERC20s array.
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

                emit ERC721IdUnregistered(erc721, id);
                break;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Updates the oracle for an erc20.
    /// @dev Only callable by owner.
    /// @param erc20 The erc20 token to update the oracle for.
    /// @param oracle The new asset's oracle.
    function updateERC20Oracle(address erc20, address oracle)
        external
        isRegisteredERC20(erc20)
        onlyOwner
    {
        // Cache old oracle.
        address oldOracle = oraclePerERC20[erc20];

        // Do nothing if new oracle is same as old oracle.
        if (oldOracle == oracle) {
            return;
        }

        // Query new oracle.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Do not accept invalid oracle response or price of zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StaleERC20PriceDeliveredByOracle(erc20, oracle);
        }

        // Update erc20's oracle and notify off-chain services.
        oraclePerERC20[erc20] = oracle;
        emit ERC20OracleUpdated(erc20, oldOracle, oracle);
    }

    /// @notice Updates the oracle for an erc721Id.
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    /// @param oracle The new asset's oracle.
    function updateERC721IdOracle(
        address erc721,
        uint id,
        address oracle
    ) external isRegisteredERC721Id(erc721, id) onlyOwner {
        // Cache old oracle.
        address oldOracle = oraclePerERC721Id[erc721][id];

        // Do nothing if new oracle is same as old oracle.
        if (oldOracle == oracle) {
            return;
        }

        // Query new oracle.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Do not accept invalid oracle response or price of zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StaleERC721IdPriceDeliveredByOracle(
                erc721,
                id,
                oracle
            );
        }

        // Update erc20's oracle and notify off-chain services.
        oraclePerERC721Id[erc721][id] = oracle;
        emit ERC721IdOracleUpdated(erc721, id, oldOracle, oracle);
    }

    //----------------------------------
    // Un/Bonding Management

    /// @notice Lists an erc20 as bondable.
    /// @dev Only callable by owner.
    /// @param erc20 The erc20 token to list as bondable.
    function listERC20AsBondable(address erc20)
        external
        isRegisteredERC20(erc20)
        onlyOwner
    {
        // Do nothing if erc20 is already listed as bondable.
        if (isERC20Bondable[erc20]) {
            return;
        }

        // Mark erc20 as being listed as bondable and notify off-chain
        // services.
        isERC20Bondable[erc20] = true;
        emit ERC20ListedAsBondable(erc20);
    }

    /// @notice Lists an erc721Id as bondable.
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    function listERC721IdAsBondable(address erc721, uint id)
        external
        isRegisteredERC721Id(erc721, id)
        onlyOwner
    {
        // Do nothing if asset is already listed as bondable.
        if (isERC721IdBondable[erc721][id]) {
            return;
        }

        // Mark erc20 as being listed as bondable and notify off-chain
        // services.
        isERC721IdBondable[erc721][id] = true;
        emit ERC721IdListedAsBondable(erc721, id);
    }

    /// @notice Delists an erc20 as bondable.
    /// @dev Only callable by owner.
    /// @param erc20 The erc20 token to delist as bondable.
    function delistERC20AsBondable(address erc20)
        external
        isRegisteredERC20(erc20)
        onlyOwner
    {
        // Do nothing if asset is already delisted as bondable.
        if (!isERC20Bondable[erc20]) {
            return;
        }

        // Mark asset as being delisted as bondable and notify off-chain
        // services.
        isERC20Bondable[erc20] = false;
        emit ERC20DelistedAsBondable(erc20);
    }

    /// @notice Delists an erc721Id as bondable.
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    function delistERC721IdAsBondable(address erc721, uint id)
        external
        isRegisteredERC721Id(erc721, id)
        onlyOwner
    {
        // Do nothing if asset is already delisted as bondable.
        if (!isERC721IdBondable[erc721][id]) {
            return;
        }

        // Mark asset as being delisted as bondable and notify off-chain
        // services.
        isERC721IdBondable[erc721][id] = false;
        emit ERC721IdDelistedAsBondable(erc721, id);
    }

    /// @notice Lists an erc20 as redeemable.
    /// @dev Only callable by owner.
    /// @param erc20 The erc20 token to list as redeemable.
    function listERC20AsRedeemable(address erc20)
        external
        isRegisteredERC20(erc20)
        onlyOwner
    {
        // Do nothing if erc20 is already listed as redeemable.
        if (isERC20Redeemable[erc20]) {
            return;
        }

        // Mark erc20 as being listed as redeemable and notify off-chain
        // services.
        isERC20Redeemable[erc20] = true;
        emit ERC20ListedAsRedeemable(erc20);
    }

    /// @notice Lists an erc721Id as redeemable.
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    function listERC721IdAsRedeemable(address erc721, uint id)
        external
        isRegisteredERC721Id(erc721, id)
        onlyOwner
    {
        // Do nothing if erc721Id is already listed as redeemable.
        if (isERC721IdRedeemable[erc721][id]) {
            return;
        }

        // Mark erc721Id as being listed as redeemable and notify off-chain
        // services.
        isERC721IdRedeemable[erc721][id] = true;
        emit ERC721IdListedAsRedeemable(erc721, id);
    }

    /// @notice Delists an erc20 as redeemable
    /// @dev Only callable by owner.
    /// @param erc20 The erc20 token to delist as redeemable.
    function delistERC20AsRedeemable(address erc20)
        external
        isRegisteredERC20(erc20)
        onlyOwner
    {
        // Do nothing if erc20 is already delisted as redeemable.
        if (!isERC20Redeemable[erc20]) {
            return;
        }

        // Mark erc20 as being delisted as redeemable and notify off-chain
        // services.
        isERC20Redeemable[erc20] = false;
        emit ERC20DelistedAsRedeemable(erc20);
    }

    /// @notice Delists an erc721 as redeemable
    /// @dev Only callable by owner.
    /// @param erc721 The erc721 token to bond.
    /// @param id     The id of the corresponding nft.
    function delistERC20AsRedeemable(address erc721, uint id)
        external
        isRegisteredERC721Id(erc721, id)
        onlyOwner
    {
        // Do nothing if erc721 is already delisted as redeemable.
        if (!isERC721IdRedeemable[erc721][id]) {
            return;
        }

        // Mark erc721 as being delisted as redeemable and notify off-chain
        // services.
        isERC721IdRedeemable[erc721][id] = false;
        emit ERC721IdDelistedAsRedeemable(erc721, id);
    }

    //--------------------------------------------------------------------------
    // Private Functions

    /// @dev Query's the price for given erc20 from the erc20's oracle.
    ///      Reverts in case the oracle or delivered price is invalid.
    function _queryERC20Price(address erc20) private view returns (uint) {
        address oracle = oraclePerERC20[erc20];
        assert(oracle != address(0));

        // Note that price is returned in 18 decimal precision.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Revert if oracle is invalid or price is zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StaleERC20PriceDeliveredByOracle(erc20, oracle);
        }

        return priceWad;
    }

    /// @dev Query's the price for given asset from the asset's oracle.
    ///      Reverts in case the oracle or delivered price is invalid.
    function _queryERC721IdPrice(address erc721, uint id)
        private
        view
        returns (uint)
    {
        address oracle = oraclePerERC721Id[erc721][id];
        assert(oracle != address(0));

        // Note that price is returned in 18 decimal precision.
        uint priceWad;
        bool valid;
        (priceWad, valid) = IOracle(oracle).getData();

        // Revert if oracle is invalid or price is zero.
        if (!valid || priceWad == 0) {
            revert Treasury__StaleERC721IdPriceDeliveredByOracle(
                erc721,
                id,
                oracle
            );
        }

        return priceWad;
    }
}
