// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IReserve {
    /// @notice An ERC721Id defines one specific ERC721 NFT token.
    ///         It is composed of the ERC721 contract address and the token's
    ///         id.
    struct ERC721Id {
        /// @dev The ERC721 contract address.
        address erc721;
        /// @dev The token's id.
        uint id;
    }

    /// @notice Each ERC20-based asset is of a certain type, either it is a regular
    ///         token, a stable token or an ecological asset (e.g. fractionalized
    ///         GeoNFTs).
    enum AssetType {
        Default,
        Stable,
        Ecological
    }

    /// @notice Each ERC20-based asset has a certain risk level, either low,
    ///         medium or high, depending on how liquid its market is and the
    ///         type of the asset.
    enum RiskLevel {
        Low,
        Medium,
        High
    }

    //--------------------------------------------------------------------------
    // Errors

    /// @notice Given token recipient invalid.
    error Reserve__InvalidRecipient();

    /// @notice Given token amount invalid.
    error Reserve__InvalidAmount();

    /// @notice Given ERC20 token address not registered.
    error Reserve__ERC20NotRegistered();

    /// @notice Given ERC721Id instance not registered.
    error Reserve__ERC721IdNotRegistered();

    /// @notice Given ERC20 token address not bondable.
    error Reserve__ERC20NotBondable();

    /// @notice Given ERC721Id instance not bondable.
    error Reserve__ERC721IdNotBondable();

    /// @notice Given ERC20 token address not redeemable.
    error Reserve__ERC20NotRedeemable();

    /// @notice Given ERC721Id instance not redeemable.
    error Reserve__ERC721IdNotRedeemable();

    /// @notice Bonding operation exceeded reserve's bonding limit for given
    ///         ERC20 token address.
    error Reserve__ERC20BondingLimitExceeded();

    /// @notice Redeem operation exceeded reserve's redeem limit for
    ///         given ERC20 token address.
    error Reserve__ERC20RedeemLimitExceeded();

    /// @notice Reserve's balance for given ERC20 token address no sufficient.
    error Reserve__ERC20BalanceNotSufficient();

    /// @notice Reserve's minimum backing limit exceeded.
    error Reserve__MinimumBackingLimitExceeded();

    /// @notice Reserve received invalid oracle response.
    error Reserve__InvalidOracle();

    //--------------------------------------------------------------------------
    // Events

    //----------------------------------
    // Reserve

    /// @notice Event emitted when reserve's backing ratio updated.
    /// @param oldBacking The old backing percentage, denominated in bps.
    /// @param newBacking The new backing percentage, denominated in bps.
    event BackingUpdated(uint oldBacking, uint newBacking);

    //----------------------------------
    // Bonding & Redeeming

    /// @notice Event emitted when ERC20 bonding operation succeeded.
    /// @param erc20 The ERC20 token address.
    /// @param erc20sBonded The amount of ERC20 tokens bonded.
    /// @param tokensMinted The amount of reserve tokens minted.
    event BondedERC20(
        address indexed erc20,
        uint erc20sBonded,
        uint tokensMinted
    );

    /// @notice Event emitted when ERC721Id instance bonding operation
    ///         succeeded.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param tokensMinted The amount of reserve tokens minted.
    event BondedERC721(address erc721, uint id, uint tokensMinted);

    /// @notice Event emitted when ERC20 redeem operation succeeded.
    /// @param erc20 The ERC20 token address.
    /// @param erc20sRedeemed The amount of ERC20 tokens redeemed.
    /// @param tokensBurned The amount of reserve tokens burned.
    event RedeemedERC20(
        address indexed erc20,
        uint erc20sRedeemed,
        uint tokensBurned
    );

    /// @notice Event emitted when ERC721Id instance redeem operation
    ///         succeeded.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param tokensBurned The amount of reserve tokens burned.
    event RedeemedERC721Id(address erc721, uint id, uint tokensBurned);

    //----------------------------------
    // Oracle Management

    /// @notice Event emitted when token's price oracle set.
    /// @param oldOracle The token's old price oracle.
    /// @param newOracle The token's new price oracle.
    event SetTokenOracle(address indexed oldOracle, address indexed newOracle);

    /// @notice Event emitted when ERC20 token's price oracle set.
    /// @param erc20 The ERC20 token address.
    /// @param oldOracle The ERC20 token's old price oracle.
    /// @param newOracle The ERC20 token's new price oracle.
    event SetERC20Oracle(
        address indexed erc20,
        address indexed oldOracle,
        address indexed newOracle
    );

    /// @notice Event emitted when ERC721Id instance's price oracle set.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param oldOracle The ERC721Id instance's old price oracle.
    /// @param newOracle The ERC721Id instance's new price oracle.
    event SetERC721IdOracle(
        address erc721,
        uint id,
        address indexed oldOracle,
        address indexed newOracle
    );

    //----------------------------------
    // Reserve Management

    /// @notice Event emitted when the reserve's minimum backing requirement
    ///         set.
    /// @param oldMinBacking The old minimum backing requirement percentage,
    ///                      denominated in bps.
    /// @param newMinBacking The new minimum backing requirement percentage,
    ///                      denominated in bps.
    event SetMinBacking(uint oldMinBacking, uint newMinBacking);

    /// @notice Event emitted when new debt incurred.
    /// @param tokenAmount The amount of tokens incurred as new debt.
    event DebtIncurred(uint tokenAmount);

    /// @notice Event emitted when debt paid.
    /// @param tokenAmount The amount of token paid as debt.
    event DebtPaid(uint tokenAmount);

    /// @notice Event emitted when ERC20 tokens are withdrawn.
    /// @param erc20 The ERC20 token address.
    /// @param recipient The address that received the withdrawn tokens
    /// @param erc20sWithdrawn The amount of ERC20 tokens withdrawn.
    event WithdrewERC20(
        address indexed erc20,
        address indexed recipient,
        uint erc20sWithdrawn
    );

    /// @notice Event emitted when an ERC721Id is withdrawn.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param recipient The address that received the withdrawn tokens
    event WithdrewERC721Id(
        address indexed erc721,
        uint indexed id,
        address indexed recipient
    );

    //----------------------------------
    // Asset Management

    /// @notice Event emitted when ERC20 token address registered.
    /// @param erc20 The ERC20 token address.
    /// @param assetType The type of the asset
    /// @param riskLevel The level of risk associated to the token
    event ERC20Registered(address indexed erc20, AssetType assetType, RiskLevel riskLevel);

    /// @notice Event emitted when ERC721 instance registered.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    event ERC721IdRegistered(address erc721, uint id);

    /// @notice Event emitted when ERC20 token addres deregistered.
    /// @param erc20 The ERC20 token address.
    event ERC20Deregistered(address indexed erc20);

    /// @notice Event emitted when ERC721Id instance deregistered.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    event ERC721IdDeregistered(address erc721, uint id);

    //----------------------------------
    // Bonding & Redeeming Management

    /// @notice Event emitted when ERC20 token listed as bondable.
    /// @param erc20 The ERC20 token address.
    event ERC20ListedAsBondable(address indexed erc20);

    /// @notice Event emitted when ERC20 token delisted as bondable.
    /// @param erc20 The ERC20 token address.
    event ERC20DelistedAsBondable(address indexed erc20);

    /// @notice Event emitted when ERC721Id instance listed as bondable.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    event ERC721IdListedAsBondable(address erc721, uint id);

    /// @notice Event emitted when ERC721Id instance delisted as bondable.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    event ERC721IdDelistedAsBondable(address erc721, uint id);

    /// @notice Event emitted when ERC20 token listed as redeemable.
    /// @param erc20 The ERC20 token address.
    event ERC20ListedAsRedeemable(address indexed erc20);

    /// @notice Event emitted when ERC20 token delisted as redeemable.
    /// @param erc20 The ERC20 token address.
    event ERC20DelistedAsRedeemable(address indexed erc20);

    /// @notice Event emitted when ERC721Id instance's listed as redeemable.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    event ERC721IdListedAsRedeemable(address erc721, uint id);

    /// @notice Event emitted when ERC721Id instance's delisted as redeemable.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    event ERC721IdDelistedAsRedeemable(address erc721, uint id);

    /// @notice Event emitted when ERC20 token's bonding limit set.
    /// @param erc20 The ERC20 token address.
    /// @param oldLimit The ERC20 token's old bonding limit.
    /// @param newLimit The ERC20 token's new bonding limit.
    event SetERC20BondingLimit(
        address indexed erc20,
        uint oldLimit,
        uint newLimit
    );

    /// @notice Event emitted when ERC20 token's redeem limit set.
    /// @param erc20 The ERC20 token address.
    /// @param oldLimit The ERC20 token's old redeem limit.
    /// @param newLimit The ERC20 token's new redeem limit.
    event SetERC20RedeemLimit(
        address indexed erc20,
        uint oldLimit,
        uint newLimit
    );

    //----------------------------------
    // Discount Management

    /// @notice Event emitted when ERC20 token's bonding discount set.
    /// @param erc20 The ERC20 token's address.
    /// @param oldDiscount The ERC20 token's old bonding discount.
    /// @param newDiscount The ERC20 token's new bonding discount.
    event SetERC20BondingDiscount(
        address indexed erc20,
        uint oldDiscount,
        uint newDiscount
    );

    /// @notice Event emitted when ERC721Id instance's bonding discount set.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param oldDiscount The ERC721Id instance's old bonding discount.
    /// @param newDiscount The ERC721Id instance's new bonding discount.
    event SetERC721IdBondingDiscount(
        address erc721,
        uint id,
        uint oldDiscount,
        uint newDiscount
    );

    //----------------------------------
    // TimeLock Management

    /// @notice Event emitted when TimeLock vault address set.
    /// @param oldTimeLockVault The old TimeLock vault's address.
    /// @param newTimeLockVault The new TimeLock vault's address.
    event SetTimeLockVault(
        address indexed oldTimeLockVault,
        address indexed newTimeLockVault
    );

    /// @notice Event emitted when ERC20 token's bonding TimeLock duration set.
    /// @param erc20 The ERC20 token's address.
    /// @param oldtimeLockDuration The ERC20 token's old bonding TimeLock
    ///                           duration.
    /// @param newtimeLockDuration The ERC20 token's new bonding TimeLock
    ///                           duration.
    event SetERC20BondingTimeLock(
        address indexed erc20,
        uint oldtimeLockDuration,
        uint newtimeLockDuration
    );

    /// @notice Event emitted when ERC721Id instance's bonding TimeLock duration set.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param oldtimeLockDuration The ERC721Id instance's old bonding TimeLock
    ///                           duration.
    /// @param newtimeLockDuration The ERC721Id instance's new bonding TimeLock
    ///                           duration.
    event SetERC721IdBondingTimeLock(
        address erc721,
        uint id,
        uint oldtimeLockDuration,
        uint newtimeLockDuration
    );

    //--------------------------------------------------------------------------
    // Mutating Functions

    //----------------------------------
    // Emergency Functions

    /// @notice Executes a call on a target.
    /// @dev Only callable by owner.
    /// @param target The address to call.
    /// @param data The call data.
    function executeTx(address target, bytes memory data) external;

    //----------------------------------
    // Token Management

    /// @notice Sets the token price oracle.
    /// @dev Only callable by owner.
    /// @param tokenOracle The token's price oracle of type IOracle.
    function setTokenOracle(address tokenOracle) external;

    //----------------------------------
    // Asset Management

    /// @notice Registers given ERC20 token with given oracle.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param oracle The ERC20 token's price oracle of type IOracle.
    /// @param assetType The asset type of the ERC20 token.
    /// @param riskLevel The level of risk associated to the ERC20 token.
    function registerERC20(
        address erc20,
        address oracle,
        AssetType assetType,
        RiskLevel riskLevel
    ) external;

    /// @notice Registers given ERC721Id instance with given oracle.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param oracle The ERC721Id instance's price oracle of type IOracle.
    function registerERC721Id(
        address erc721,
        uint id,
        address oracle
    ) external;

    /// @notice Deregisters given ERC20 token.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function deregisterERC20(address erc20) external;

    /// @notice Deregisters given ERC721Id instance.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function deregisterERC721Id(address erc721, uint id) external;

    /// @notice Updates the price oracle for given ERC20 token.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token.
    /// @param oracle The new token's price oracle of type IOracle.
    function updateOracleForERC20(address erc20, address oracle) external;

    /// @notice Updates the price oracle for given ERC721Id instance.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param oracle The new ERC721Id instance's price oracle of type IOracle.
    function updateOracleForERC721Id(
        address erc721,
        uint id,
        address oracle
    ) external;

    //----------------------------------
    // Bonding & Redeeming Management

    /// @notice Lists given ERC20 token as bondable.
    /// @dev ERC20 token must be registered already.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function listERC20AsBondable(address erc20) external;

    /// @notice Delists given ERC20 token as bondable.
    /// @dev ERC20 token must be registered already.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function delistERC20AsBondable(address erc20) external;

    /// @notice Lists given ERC721Id instance as bondable.
    /// @dev ERC721 instance must be registered already.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function listERC721IdAsBondable(address erc721, uint id) external;

    /// @notice Delists given ERC721Id instance as bondable.
    /// @dev ERC721 instance must be registered already.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function delistERC721IdAsBondable(address erc721, uint id) external;

    /// @notice Lists given ERC20 token as redeemable.
    /// @dev ERC20 token must be registered already.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function listERC20AsRedeemable(address erc20) external;

    /// @notice Delists given ERC20 token as redeemable.
    /// @dev ERC20 token must be registered already.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    function delistERC20AsRedeemable(address erc20) external;

    /// @notice Lists given ERC721Id instance as redeemable.
    /// @dev ERC721 instance must be registered already.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function listERC721IdAsRedeemable(address erc721, uint id) external;

    /// @notice Delists given ERC721Id instance as redeemable.
    /// @dev ERC721 instance must be registered already.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function delistERC721IdAsRedeemable(address erc721, uint id) external;

    /// @notice Sets the maximum balance of given ERC20 token allowed in the
    ///         reserve.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param limit The upper balance limit for the ERC20 token.
    function setERC20BondingLimit(address erc20, uint limit) external;

    /// @notice Sets the minimum balance of given ERC20 token allowed in the
    ///         reserve.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param limit The lower balance limit for the ERC20 token.
    function setERC20RedeemLimit(address erc20, uint limit) external;

    //----------------------------------
    // Discount Management

    /// @notice Sets a bonding discount percentage, denominated in bps, for
    ///         given ERC20 token.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param discount The bonding discount for the ERC20 token.
    function setBondingDiscountForERC20(address erc20, uint discount) external;

    /// @notice Sets a bonding discount percentage, denominated in bps, for
    ///         given ERC721Id instance.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param discount The bonding discount for the ERC721Id instance.
    function setBondingDiscountForERC721Id(
        address erc721,
        uint id,
        uint discount
    ) external;

    //----------------------------------
    // TimeLock Management

    /// @notice Sets the TimeLock vault to use for vested bonds.
    /// @dev Only callable by owner.
    /// @param timeLockVault The TimeLock vault address of type ITimeLockVault.
    function setTimeLockVault(address timeLockVault) external;

    /// @notice Sets the bonding TimeLock duration for given ERC20 token.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param timeLockDuration The bonding TimeLock duration for the ERC20 token.
    function setBondingTimeLockForERC20(address erc20, uint timeLockDuration)
        external;

    /// @notice Sets the bonding TimeLock duration for given ERC721Id instance.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param timeLockDuration The bonding TimeLock duration for the ERC721Id
    ///        instance.
    function setBondingTimeLockForERC721Id(
        address erc721,
        uint id,
        uint timeLockDuration
    ) external;

    //---------------------------------
    // Bundle Functions

    /// @notice Bundles the listing of a new ERC20 bond together with
    ///         setting it's limit so it can be done in one tx.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param limit The bonding limit for the ERC20 token.
    /// @param discount The bonding discount for the ERC20 token.
    /// @param timeLockDuration The TimeLock duration for the ERC20 token.
    function setupAndListERC20Bond(
        address erc20, 
        uint limit, 
        uint discount, 
        uint timeLockDuration
    ) external;

    /// @notice Bundles the listing of a new ERC20 redemption together
    ///         with setting it's limit so it can be done in one tx.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param limit The redeem limit for the ERC20 token.
    function setupAndListERC20Redemption(
        address erc20, 
        uint limit
    ) external;

    /// @notice Bundles the listing of a new ERC721Id bond together
    ///          with setting it's limit so it can be done in one tx.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param discount The bonding discount for the ERC721Id.
    /// @param timeLockDuration The TimeLock duration for the ERC721Id.
    function setupAndListERC721IdBond(
        address erc721, 
        uint id,
        uint discount, 
        uint timeLockDuration
    ) external;

    /// @notice Bundles the listing of a new ERC721Id redemption together
    ///          with setting it's limit so it can be done in one tx.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function setupAndListERC721IdRedemption(
        address erc721, 
        uint id
    ) external;

    //---------------------------------
    // Reserve Management

    /// @notice Sets the minimum backing requirement percentage, denominated
    ///         in bps, for the reserve.
    /// @dev Only callable by owner.
    /// @param minBacking The minimum backing requirement.
    function setMinBacking(uint minBacking) external;

    /// @notice Withdraws given amount of ERC20 tokens to given recipient.
    /// @dev Reverts in case the minimum backing requirement is exceeded.
    /// @dev Only callable by owner.
    /// @param erc20 The ERC20 token address.
    /// @param recipient The recipient address for the withdrawed ERC20 tokens.
    /// @param amount The amount of the asset to withdraw.
    function withdrawERC20(
        address erc20,
        address recipient,
        uint amount
    ) external;

    /// @notice Withdraws given ERC721Id instance to given recipient.
    /// @dev Reverts in case the minimum backing requirement is exceeded.
    /// @dev Only callable by owner.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param recipient The recipient address for the withdrawed ERC721Id
    ///                  instance.
    function withdrawERC721Id(
        address erc721,
        uint id,
        address recipient
    ) external;

    /// @notice Incurs debt by minting tokens to the caller.
    /// @dev Reverts in case the minimum backing requirement is exceeded.
    /// @dev Only callable by owner.
    /// @param amount The amount of tokens to mint.
    function incurDebt(uint amount) external;

    /// @notice Pays debt by burning tokens from the caller.
    /// @dev Only callable by owner.
    /// @param amount The amount of tokens to burn.
    function payDebt(uint amount) external;

    //----------------------------------
    // Bonding & Redeeming Functions

    /// @notice Bonds given amount of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc20 The ERC20 token address.
    /// @param amount The amount of ERC20 tokens to bond.
    function bondERC20(address erc20, uint amount) external;

    /// @notice Bonds given amount of ERC20 tokens from given address and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc20 The ERC20 token address.
    /// @param from The address to fetch ERC20 tokens from.
    /// @param amount The amount of ERC20 tokens to bond.
    function bondERC20From(
        address erc20,
        address from,
        uint amount
    ) external;

    /// @notice Bonds given amount of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc20 The ERC20 token address.
    /// @param recipient The recipient address for the reserve tokens.
    /// @param amount The amount of ERC20 tokens to bond.
    function bondERC20To(
        address erc20,
        address recipient,
        uint amount
    ) external;

    /// @notice Bonds given amount of ERC20 tokens from given address and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc20 The ERC20 token address.
    /// @param from The address to fetch ERC20 tokens from.
    /// @param recipient The recipient address for the reserve tokens.
    /// @param amount The amount of ERC20 tokens to bond.
    function bondERC20FromTo(
        address erc20,
        address from,
        address recipient,
        uint amount
    ) external;

    /// @notice Bonds whole balance of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc20 The ERC20 token address.
    function bondERC20All(address erc20) external;

    /// @notice Bonds whole balance of ERC20 tokens from given address and mints
    ///         corresponding reserve tokens to the caller.
    /// @param from The address to fetch ERC20 tokens from.
    /// @param erc20 The ERC20 token address.
    function bondERC20AllFrom(address erc20, address from) external;

    /// @notice Bonds whole balance of ERC20 tokens from the caller and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc20 The ERC20 token address.
    /// @param recipient The recipient address for the reserve tokens.
    function bondERC20AllTo(address erc20, address recipient) external;

    /// @notice Bonds whole balance of ERC20 tokens from given address and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc20 The ERC20 token address.
    /// @param from The address to fetch ERC20 tokens from.
    /// @param recipient The recipient address for the reserve tokens.
    function bondERC20AllFromTo(
        address erc20,
        address from,
        address recipient
    ) external;

    /// @notice Bonds given ERC721Id instance from caller and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function bondERC721Id(address erc721, uint id) external;

    /// @notice Bonds given ERC721Id instance from given address and mints
    ///         corresponding reserve tokens to the caller.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param from The address to fetch the ERC721Id instance from.
    function bondERC721IdFrom(
        address erc721,
        uint id,
        address from
    ) external;

    /// @notice Bonds given ERC721Id instance from caller and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param recipient The recipient address for the reserve tokens.
    function bondERC721IdTo(
        address erc721,
        uint id,
        address recipient
    ) external;

    /// @notice Bonds given ERC721Id instance from given address and mints
    ///         corresponding reserve tokens to given recipient.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param from The address to fetch the ERC721Id instance from.
    /// @param recipient The recipient address for the reserve tokens.
    function bondERC721IdFromTo(
        address erc721,
        uint id,
        address from,
        address recipient
    ) external;

    /// @notice Redeems some amount of given ERC20 token to the caller and
    ///         burns given amount of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to redeem.
    /// @param tokenAmount The amount of reserve tokens to burn.
    function redeemERC20(address erc20, uint tokenAmount) external;

    /// @notice Redeems some amount of given ERC20 token to the caller and
    ///         burns given amount of reserve tokens from given address.
    /// @param erc20 The ERC20 token to redeem.
    /// @param from The address to fetch the reserve tokens from.
    /// @param tokenAmount The amount of reserve tokens to burn.
    function redeemERC20From(
        address erc20,
        address from,
        uint tokenAmount
    ) external;

    /// @notice Redeems some amount of given ERC20 token to given recipient and
    ///         burns given amount of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to redeem.
    /// @param recipient The recipient address for the redeemed ERC20 tokens.
    /// @param tokenAmount The amount of reserve tokens to burn.
    function redeemERC20To(
        address erc20,
        address recipient,
        uint tokenAmount
    ) external;

    /// @notice Redeems some amount of given ERC20 token to given recipient and
    ///         burns given amount of reserve tokens from given address.
    /// @param erc20 The ERC20 token to redeem.
    /// @param from The address to fetch the reserve tokens from.
    /// @param recipient The recipient address for the redeemed ERC20 tokens.
    /// @param tokenAmount The amount of reserve tokens to burn.
    function redeemERC20FromTo(
        address erc20,
        address from,
        address recipient,
        uint tokenAmount
    ) external;

    /// @notice Redeems some amount of given ERC20 token to the caller and
    ///         burns whole balance of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to redeem.
    function redeemERC20All(address erc20) external;

    /// @notice Redeems some amount of given ERC20 token to the caller and
    ///         burns whole balance of reserve tokens from given address.
    /// @param erc20 The ERC20 token to redeem.
    /// @param from The address to fetch the reserve tokens from.
    function redeemERC20AllFrom(address erc20, address from) external;

    /// @notice Redeems some amount of given ERC20 token to given recipient and
    ///         burns whole balance of reserve tokens from the caller.
    /// @param erc20 The ERC20 token to redeem.
    /// @param recipient The recipient address for the redeemed ERC20 tokens.
    function redeemERC20AllTo(address erc20, address recipient) external;

    /// @notice Redeems some amount of given ERC20 token to given recipient and
    ///         burns whole balance of reserve tokens from given address.
    /// @param erc20 The ERC20 token to redeem.
    /// @param from The address to fetch the reserve tokens from.
    /// @param recipient The recipient address for the redeemed ERC20 tokens.
    function redeemERC20AllFromTo(
        address erc20,
        address from,
        address recipient
    ) external;

    /// @notice Redeems given ERC721Id instance to the caller and burns
    ///         corresponding amount of reserve tokens from the caller.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    function redeemERC721Id(address erc721, uint id) external;

    /// @notice Redeems given ERC721Id instance to given recipient and burns
    ///         corresponding amount of reserve tokens from given address.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param from The address to fetch the ERC721Id instance from.
    function redeemERC721IdFrom(
        address erc721,
        uint id,
        address from
    ) external;

    /// @notice Redeems given ERC721Id instance to given recipient and burns
    ///         corresponding amount of reserve tokens from the caller.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param recipient The recipient address for the redeemed ERC721Id
    ///                  instance.
    function redeemERC721IdTo(
        address erc721,
        uint id,
        address recipient
    ) external;

    /// @notice Redeems given ERC721Id instance to given recipient and burns
    ///         corresponding amount of reserve tokens from the caller.
    /// @param erc721 The ERC721 token address.
    /// @param id The id of the corresponding NFT.
    /// @param from The address to fetch the ERC721Id instance from.
    /// @param recipient The recipient address for the redeemed ERC721Id
    ///                  instance.
    function redeemERC721IdFromTo(
        address erc721,
        uint id,
        address from,
        address recipient
    ) external;

    //--------------------------------------------------------------------------
    // View Functions

    /// @notice Returns the token address the reserve is backing.
    function token() external view returns (address);

    /// @notice Returns the registered ERC20 token address at given index.
    function registeredERC20s(uint index) external view returns (address);

    /// @notice Returns the registered ERC721Id instance at given index.
    function registeredERC721Ids(uint index)
        external
        view
        returns (address, uint);

    /// @notice Returns the registered ERC20 tokens.
    function allRegisteredERC20s() external view returns (address[] memory);

    /// @notice Returns the registered ERC721Id instances.
    function allRegisteredERC721Ids() external view returns (ERC721Id[] memory);

    /// @notice Returns the type of a registered erc20 asset.
    function assetTypeOfERC20(address erc20) external view returns (AssetType);

    /// @notice Returns the risk level of a registered erc20 asset.
    function riskLevelOfERC20(address erc20) external view returns (RiskLevel);
    //----------------------------------
    // TimeLock View Functions

    /// @notice Returns the reserve's TimeLock vault address used for vested
    ///         bonding operations.
    /// @dev Changeable by owner.
    /// @dev Is of type ITimeLockVault.
    function timeLockVault() external view returns (address);

    //----------------------------------
    // Oracle View Functions

    /// @notice Returns the reserve's token's price oracle address.
    /// @dev Changeable by owner.
    /// @dev Is of type IOracle.
    function tokenOracle() external view returns (address);

    /// @notice Returns the price oracle for given ERC20 token address.
    /// @param erc20 The ERC20 token address.
    /// @return The ERC20 token's price oracle address of type IOracle.
    function oraclePerERC20(address erc20) external view returns (address);

    /// @notice Returns the price oracle for the ERC721Id instance, identified
    ///         through given address and id.
    /// @param erc721 The ERC721 token's address.
    /// @param id     The NFTs corresponding id.
    /// @return The ERC721Id instance's price oracle address of type IOracle.
    function oraclePerERC721Id(address erc721, uint id)
        external
        view
        returns (address);

    //----------------------------------
    // Bonding & Redeeming View Functions

    /// @notice Returns whether the given ERC20 token address is bondable.
    /// @param erc20 The ERC20 token address.
    /// @return Whether the ERC20 token address is bondable.
    function isERC20Bondable(address erc20) external view returns (bool);

    /// @notice Returns whether the ERC721Id instance, identified through
    ///         given address and id, is bondable.
    /// @param erc721 The ERC721 token's address.
    /// @param id     The NFTs corresponding id.
    /// @return Whether the ERC721Id instance is bondable.
    function isERC721IdBondable(address erc721, uint id)
        external
        view
        returns (bool);

    /// @notice Returns whether the given ERC20 token address is redeemable.
    /// @param erc20 The ERC20 token address.
    /// @return Whether the ERC20 token address is redeemable.
    function isERC20Redeemable(address erc20) external view returns (bool);

    /// @notice Returns whether the ERC721Id instance, identified through given
    ///         address and id, is redeemable.
    /// @param erc721 The ERC721 token's address.
    /// @param id     The NFTs corresponding id.
    /// @return Whether the ERC721Id instance is redeemable.
    function isERC721IdRedeemable(address erc721, uint id)
        external
        view
        returns (bool);

    /// @notice Returns the bonding limit for given ERC20 token address.
    /// @dev A limit of zero is treated as infinite, i.e. no limit set.
    /// @param erc20 The ERC20 token address.
    /// @return The bonding limit for given ERC20 token address.
    function bondingLimitPerERC20(address erc20) external view returns (uint);

    /// @notice Returns the redeem limit for given ERC20 token address.
    /// @param erc20 The ERC20 token address.
    /// @return The redeem limit for given ERC20 token address.
    function redeemLimitPerERC20(address erc20) external view returns (uint);

    //----------------------------------
    // Discount View Functions

    /// @notice Returns the bonding discount percentage, denominated in bps,
    ///         for given ERC20 token address.
    /// @param erc20 The ERC20 token address.
    /// @return The bonding discount percentage, denomintated in bps, for
    ///         given ERC20 token address.
    function bondingDiscountPerERC20(address erc20)
        external
        view
        returns (uint);

    /// @notice Returns the bonding discount percentage, denominated in bps,
    ///         for the ERC721Id instance, identified through given address and id.
    /// @param erc721 The ERC721 token's address.
    /// @param id     The NFTs corresponding id.
    /// @return The bonding discount percentage, denomintated in bps, for given
    ///         ERC721Id instance.
    function bondingDiscountPerERC721Id(address erc721, uint id)
        external
        view
        returns (uint);

    //----------------------------------
    // TimeLock View Mappings

    /// @notice Returns the bonding TimeLock duration for given ERC20 token
    ///         address.
    /// @param erc20 The ERC20 token address.
    /// @return The bonding TimeLock duration for given ERC20 token address.
    function bondingTimeLockDurationPerERC20(address erc20)
        external
        view
        returns (uint);

    /// @notice Returns the bonding TimeLock duration for the ERC721Id instance,
    ///         identified through address and id.
    /// @param erc721 The ERC721 token's address.
    /// @param id     The NFTs corresponding id.
    /// @return The bonding TimeLock duration for given ERC721Id instance.
    function bondingTimeLockDurationPerERC721Id(address erc721, uint id)
        external
        view
        returns (uint);

    //----------------------------------
    // Reserve Management

    /// @notice The minimum backing percentage, denominated in bps, of token
    ///         supply backed by the reserve.
    /// @dev Changeable by owner.
    function minBacking() external view returns (uint);

    /// @notice Returns the last computed Reserve's status.
    /// @return uint Reserve assets valuation in USD with 18 decimal precision.
    /// @return uint Token supply's valuation in USD with 18 decimal precision.
    /// @return uint BPS of supply backed by reserve.
    function reserveStatus()
        external
        view
        returns (
            uint,
            uint,
            uint
        );
}
