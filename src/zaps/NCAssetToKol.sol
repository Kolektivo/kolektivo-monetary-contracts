// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface ITreasury {
    function bond(address asset, uint amount) external;
}

interface IReserve {
    function depositAllFor(address to) external;
}

/**
 * @title Natural Capital Assets to KOL token Zapper
 *
 * @dev Stateless Zapper contract enabling depositing Natural Capital Asset
 *      in the Treasury and receiving KOL tokens from the Reserve.
 *
 *      The token flow is a follows:
 *              NCAsset     (fetched from user account)
 *                 ↓
 *                 ↓ deposit into Treasury
 *                 ↓
 *             KTT tokens   (held in Zapper contract)
 *                 ↓
 *                 ↓ deposit into Reserve
 *                 ↓
 *             KOL tokens   (send to user account)
 *
 *      Note that the natural capital asset needs to be supported by the
 *      treasury, otherwise the zap() call will fail.
 *
 * @author byterocket
 */
contract NCAssetToKol {

    ITreasury private immutable _treasury;

    IReserve private immutable _reserve;

    constructor(address treasury, address reserve, address ktt) {
        require(treasury != address(0));
        require(reserve != address(0));

        _treasury = ITreasury(treasury);
        _reserve = IReserve(reserve);

        // Give inifinite approval of KTT tokens to the reserve.
        ERC20(ktt).approve(reserve, type(uint).max);
    }

    function zap(address ncAsset, uint amount) external returns (bool) {
        // Fetch assets from msg.sender.
        ERC20(ncAsset).safeTransferFrom(msg.sender, address(this), amount);

        // Bond assets and receive KTT tokens.
        _treasury.bond(ncAsset, amount);

        // Deposit whole KTT balance for msg.sender into reserve.
        // Note that any KTT tokens send accidently to this contract are
        // therefore attributed to the next user calling this function.
        _reserve.depositAllFor(msg.sender);
    }

    /// @notice Returns the treasury address.
    function treasury() external view returns (address) {
        return address(_treasury);
    }

    /// @notice Returns the reserve address.
    function reserve() external view returns (address) {
        return address(_reserve);
    }

}
