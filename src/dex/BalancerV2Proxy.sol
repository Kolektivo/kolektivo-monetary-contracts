// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";
import "./lib/IUniswapV2Router02.sol";
import "../interfaces/IReserve.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "./IVault.sol";

interface CuracaoReserveToken {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}

contract BalancerV2Proxy is TSOwnable, Pausable {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Constants and Immutables

    /// @dev 10,000 bps are 100%.
    uint256 private constant BPS = 10_000;

    ERC20 public pairToken;
    IVault public vault;
    IReserve public reserve;
    address public reserveToken;
    // @dev 10,000 is 10 | 50,000 is 50
    // @note ceiling multiplier is not a percent but a constant number
    uint256 public ceilingMultiplier;
    uint256 public ceilingTradeShare;
    uint256 public floorTradeShare;

    // following varaibles are used by functions as temporary variables to store temporary data
    // at the start of functional calls, their value is always zero
    // at the end of functional calls, their value is again set to zero
    // this is done to prevent call stack being exceeded
    uint256 public inBalanceBefore;
    uint256 public inBalanceAfter;
    uint256 public outBalanceBefore;
    uint256 public outBalanceAfter;

    constructor(
        address pairToken_,
        address vault_,
        address reserve_,
        uint256 ceilingMultiplier_,
        uint256 ceilingTradeShare_,
        uint256 floorTradeShare_
    ) {
        require(pairToken_ != address(0));
        require(vault_ != address(0));
        require(reserve_ != address(0));
        require(ceilingMultiplier_ != 0);
        require(ceilingTradeShare_ <= BPS);
        require(floorTradeShare_ <= BPS);

        // Set storage.
        pairToken = ERC20(pairToken_);
        vault = IVault(vault_);
        reserve = IReserve(reserve_);
        ceilingMultiplier = ceilingMultiplier_;
        ceilingTradeShare = ceilingTradeShare_;
        floorTradeShare = floorTradeShare_;
        reserveToken = reserve.token();
        require(reserveToken != address(0));
    }

    // assets array [addressOfTokenIn, addressOfTokenOut]
    // totalAmountIn - exact amount in
    // minTotalAmountOut - minimum total amount the swap should withdraw
    // funds - struct of FundManagement where all the internal balance option is false
    // limits - [] empty array
    // deadline - can be set to an hour (used previously in Prime Launch)
    function batchSwapExactIn(
        IVault.BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        uint256 totalAmountIn,
        uint256 minTotalAmountOut,
        IVault.FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external payable whenNotPaused {
        require(
            (address(assets[0]) == reserveToken && address(assets[1]) == address(pairToken))
                || (address(assets[0]) == address(pairToken) && address(assets[1]) == reserveToken)
        );
        require(swaps.length == 1);

        if (address(assets[0]) == reserveToken) {
            // User sells Reserve Token for the Pair Token
            inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            outBalanceBefore = pairToken.balanceOf(address(this));

            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), totalAmountIn);
            uint256 thisAmountIn = totalAmountIn;
            uint256 thisAmountOutMin = minTotalAmountOut;

            // Calculate the amount that we will withdraw from the Reserve instead of
            // acquiring it on the vault
            uint256 withdrawAmount = (thisAmountOutMin * floorTradeShare) / BPS;

            {
                (bool breach, bool isFloor) = _checkReserveLimits();
                // If a limit is breached in the Reserve and it is the floor
                // (for ceiling we don't care if a user sells Reserve Tokens since it helps us)
                if (breach && isFloor) {
                    // Retrieve the corresponding amount from the Reserve
                    reserve.withdrawERC20(address(pairToken), address(this), withdrawAmount);
                    thisAmountIn = (thisAmountIn * withdrawAmount) / thisAmountOutMin;
                    thisAmountOutMin = thisAmountOutMin - withdrawAmount;

                    swaps[0].amount = thisAmountIn / thisAmountOutMin;
                }
            }

            // Approve and execute the vault swap
            {
                ERC20(reserveToken).approve(address(vault), thisAmountIn);
                uint256 outAmount = uint256(
                    vault.batchSwap( // exact in
                    IVault.SwapKind.GIVEN_IN, swaps, assets, funds, limits, deadline)[1] // token out is at index 1, hence the balance delta at index 1 is the balance of tokenOut which was withdrawn from vault/pool
                );

                // Update the exchange return value with our additional amount
                outAmount += withdrawAmount;
                require(outAmount >= minTotalAmountOut);
            }

            inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            outBalanceAfter = pairToken.balanceOf(address(this));

            // Transfer the resulting tokens to the user
            pairToken.transfer(msg.sender, outBalanceAfter - outBalanceBefore);

            // Burn the surplus of Reserve Tokens that we didn't see on the exchange
            CuracaoReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
            outBalanceBefore = 0;
            outBalanceAfter = 0;
        } else if (address(assets[1]) == reserveToken) {
            // User buys Reserve Token with the Pair Token
            inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), totalAmountIn);
            uint256 thisAmountIn = totalAmountIn;
            uint256 thisAmountOutMin = minTotalAmountOut;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint256 mintAmount = (thisAmountOutMin * ceilingTradeShare) / BPS;

            {
                (bool breach, bool isFloor) = _checkReserveLimits();
                // If a limit is breached in the Reserve and it is the ceiling
                // (for floor we don't care if a user buys Reserve Tokens since it helps us)
                if (breach && !isFloor) {
                    // Mint the corresponding amount from the Reserve
                    CuracaoReserveToken(reserveToken).mint(address(this), mintAmount);
                    thisAmountIn = (thisAmountIn * mintAmount) / thisAmountIn;
                    thisAmountOutMin = thisAmountOutMin - mintAmount;

                    swaps[0].amount = thisAmountIn / thisAmountOutMin;
                }
            }
            // Approve and execute the exchange swap
            {
                pairToken.approve(address(vault), thisAmountIn);
                uint256 outAmount = uint256(
                    vault.batchSwap( // exact in
                    IVault.SwapKind.GIVEN_IN, swaps, assets, funds, limits, deadline)[1] // token out is at index 1, hence the balance delta at index 1 is the balance of tokenOut which was withdrawn from vault/pool
                );

                // Update the exchange return value with our additional amount
                outAmount += mintAmount;
                require(outAmount >= minTotalAmountOut);
            }

            inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the resulting tokens to the user
            ERC20(reserveToken).transfer(msg.sender, inBalanceAfter - inBalanceBefore);
        }
        inBalanceBefore = 0;
        inBalanceAfter = 0;
    }

    function batchSwapExactOut(
        IVault.BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        uint256 maxTotalAmountIn,
        IVault.FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external payable whenNotPaused {
        require(
            (address(assets[0]) == reserveToken && address(assets[1]) == address(pairToken))
                || (address(assets[0]) == address(pairToken) && address(assets[1]) == reserveToken)
        );
        require(swaps.length == 1);

        if (address(assets[0]) == reserveToken) {
            // User sells Reserve Token for the Pair Token
            // check the existing balance of the Proxy Pool Contract
            inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            outBalanceBefore = pairToken.balanceOf(address(this));

            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), maxTotalAmountIn);
            uint256 thisAmountOut = swaps[0].amount; // if swap kind is GEVEN_OUT, swap.amount -> exact amout out
            uint256 thisAmountInMax = maxTotalAmountIn;

            // Calculate the amount that we will withdraw from the Reserve instead of
            // acquiring it on the exchange
            uint256 withdrawAmount = (thisAmountOut * floorTradeShare) / BPS;

            {
                (bool breach, bool isFloor) = _checkReserveLimits();
                // If a limit is breached in the Reserve and it is the floor
                // (for ceiling we don't care if a user sells Reserve Tokens since it helps us)
                if (breach && isFloor) {
                    // Retrieve the corresponding amount from the Reserve
                    reserve.withdrawERC20(address(pairToken), address(this), withdrawAmount);
                    thisAmountInMax = (thisAmountInMax * withdrawAmount) / thisAmountOut;
                    thisAmountOut = thisAmountOut - withdrawAmount;
                }
            }
            // Approve and execute the exchange swap
            ERC20(reserveToken).approve(address(vault), thisAmountInMax);
            vault.batchSwap( // exact out
            IVault.SwapKind.GIVEN_OUT, swaps, assets, funds, limits, deadline);

            inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            outBalanceAfter = pairToken.balanceOf(address(this));
            {
                uint256 inAmount = inBalanceAfter - inBalanceBefore;
                uint256 outAmount = outBalanceAfter - outBalanceBefore + withdrawAmount;
                require(inAmount <= maxTotalAmountIn && outAmount >= thisAmountOut);
            }

            // Transfer the resulting tokens to the user
            pairToken.transfer(msg.sender, outBalanceAfter - outBalanceBefore);

            // Burn the surplus of Reserve Tokens
            CuracaoReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
        } else if (address(assets[1]) == reserveToken) {
            // User buys Reserve Token with the Pair Token
            inBalanceBefore = pairToken.balanceOf(address(this));
            outBalanceBefore = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), maxTotalAmountIn);
            uint256 thisAmountOut = swaps[0].amount; // if swap kind is GEVEN_OUT, swap.amount -> exact amout out
            uint256 thisAmountInMax = maxTotalAmountIn;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint256 mintAmount = (thisAmountOut * ceilingTradeShare) / BPS;

            {
                (bool breach, bool isFloor) = _checkReserveLimits();
                // If a limit is breached in the Reserve and it is the ceiling
                // (for floor we don't care if a user buys Reserve Tokens since it helps us)
                if (breach && !isFloor) {
                    // Mint the corresponding amount from the Reserve
                    CuracaoReserveToken(reserveToken).mint(address(this), mintAmount);
                    thisAmountInMax = (thisAmountInMax * mintAmount) / thisAmountOut;
                    thisAmountOut = thisAmountOut - mintAmount;
                }
            }
            // Approve and execute the exchange swap
            pairToken.approve(address(vault), thisAmountInMax);
            vault.batchSwap( // exact out
            IVault.SwapKind.GIVEN_OUT, swaps, assets, funds, limits, deadline); // exact out

            inBalanceAfter = pairToken.balanceOf(address(this));
            outBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            {
                uint256 inAmount = inBalanceBefore - inBalanceAfter;
                uint256 outAmount = outBalanceAfter - outBalanceBefore + mintAmount;
                require(inAmount <= maxTotalAmountIn && outAmount >= thisAmountOut);

                // Transfer the resulting tokens to the user
                ERC20(reserveToken).transfer(msg.sender, outAmount);
            }
        }
        outBalanceAfter = 0;
        outBalanceBefore = 0;
        inBalanceAfter = 0;
        inBalanceBefore = 0;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
 
    function _checkReserveLimits() internal view returns (bool, bool) {
        // reserve backing - percentage of supply backed by reserve
        // as we take some leverage, not whole supply is backed by reserve
        (,, uint256 reserveBacking) = reserve.reserveStatus();

        // Floor
        // checks following
        // current floor price <= current kCur price
        // below condition is a derived condition which in the end checks same logic
        if (reserveBacking > BPS) {
            return (true, true);
        }

        // Ceiling
        // check following
        // current kCur price > current floor price * ceiling multiplier
        // below condition is a derived condition which in the end checks the same logic
        // ceilingMultiplier -> if 3.5 = 35000
        if (reserveBacking * ceilingMultiplier < BPS * BPS) {
            return (true, false);
        }

        return (false, false);
    }
}
