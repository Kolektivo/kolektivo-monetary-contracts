// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {TSOwnable} from "solrocket/TSOwnable.sol";
import {Whitelisted} from "solrocket/Whitelisted.sol";

import {Treasury} from "./Treasury.sol";

import {IOracle} from "./interfaces/IOracle.sol";
import {IReserve2} from "./interfaces/IReserve2.sol";

import {Wad} from "./lib/Wad.sol";

/**
 Notes:
    - supported means asset has an oracle and is being taking into account
      for the backing calculation.
    - KTT is no special token anymore. We make oracle for KTT and treat it as normal ERC20.
        - ok
    - max un/bonding not implemented. I think it's better to observe and disable per backend.
        - @todo insgesamt XXX erc20 amount darf gebonded werden.
    - For backing calculation: Should we have oracle for KOL/token? Or assume 1$? O.o
        - mit oracle fuer KOL
 */

// @todo Check for grammar tool in VSCode.

/**
 TODOs:
    -
 */

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
    ERC20 private immutable _token;
    address private immutable _tokenOracle;

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

    // uint = percentage amount freed per day?
    mapping(address => uint) public vestingPerERC20;
    mapping(bytes32 => uint) public vestingPerERC721Id;

    mapping(address => mapping(address => VestedDeposit)) public vestedDepositPerUserPerERC20;
    mapping(address => mapping(bytes32 => VestedDeposit)) public vestedDepositPerUserPerERC721Id;

    //----------------------------------
    // Reserve Management

    uint private _backing;
    uint public minBacking;

    //--------------------------------------------------------------------------
    // Constructor

    constructor(address token_, address tokenOracle_, uint minBacking_) {
        require(token_ != address(0));
        require(token_.code.length != 0);

        // Check that tokenOracle delivers valid data.
        bool valid;
        (/*price*/, valid) = _queryOracle(tokenOracle_);
        require(valid);

        // Set storage.
        _token = ERC20(token_);
        _tokenOracle = tokenOracle_;
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
        uint oldVesting = vestingPerERC20[erc20];

        if (vesting != oldVesting) {
            vestingPerERC20[erc20] = vesting;
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
        uint oldVesting = vestingPerERC721Id[erc721IdHash];

        if (vesting != oldVesting) {
            discountPerERC721Id[erc721IdHash] = vesting;
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
        // @todo Add interface with mint/burn functions.
        //_token.mint(msg.sender, amount);

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
        // @todo Add interface with mint/burn functions.
        //_token.burn(msg.sender, amount);

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
        address from,
        address to,
        address erc20,
        uint erc20Amount
    )
        private
        onBeforeUpdateBacking(true)
    {
        // @todo Add discount and vesting.

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

        // @todo Should mint on token = 1$ basis or use token's oracle?
        // Mint tokens.
        // @todo Add interface with mint/burn functions.
        //_token.mint(to, valuationWad);
    }

    function _bondERC721Id(
        address from,
        address to,
        ERC721Id memory erc721Id
    )
        private
        onBeforeUpdateBacking(true)
    {
        // @todo Add discount and vesting.
        bytes32 erc721IdHash = _hashOfERC721Id(erc721Id);

        // Fetch erc721Id.
        ERC721(erc721Id.erc721).safeTransferFrom(
            from,
            address(this),
            erc721Id.id
        );

        // Query erc721Id's price oracle.
        // Note that the price equals the valuation as the amount bonded is
        // always 1.
        bool valid;
        uint priceWad;
        (priceWad, valid) = _queryOracle(oraclePerERC721Id[erc721IdHash]);
        if (!valid) {
            revert("Invalid Oracle");
        }

        // @todo Should mint on token = 1$ basis or use token's oracle?
        // Mint tokens.
        // @todo Add interface with mint/burn functions.
        //_token.mint(to, priceWad);
    }

    //----------------------------------
    // Unbond Functions

    function _unbondERC20(
        address to,
        address from,
        address erc20,
        uint tokenAmount
    )
        private
        onBeforeUpdateBacking(true)
    {

    }

    function _unbondERC721Id(
        address to,
        address from,
        ERC721Id memory erc721Id,
        uint tokenAmount
    )
        private
        onBeforeUpdateBacking(true)
    {

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

            // Query oracle for erc20's price.
            (priceWad, valid) = _queryOracle(oraclePerERC20[erc20]);
            if (!valid) {
                revert("Invalid oracle");
            }

            // Fetch erc20 balance in wad format.
            balanceWad = Wad.convertToWad(
                erc20,
                ERC20(erc20).balanceOf(address(this))
            );

            // Continue/Break if there is no asset balance.
            if (balanceWad == 0) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked { ++i; }
                    continue;
                }
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

            // Query oracle for erc721Id's price.
            (priceWad, valid) = _queryOracle(oraclePerERC721Id[erc721IdHash]);
            if (!valid) {
                revert("Invalid oracle");
            }

            // Continue/Break if reserve is not the owner of that erc721Id.
            if (ERC721(erc721Id.erc721).ownerOf(erc721Id.id) != address(this)) {
                if (i + 1 == len) {
                    break;
                } else {
                    unchecked { ++i; }
                    continue;
                }
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

}
