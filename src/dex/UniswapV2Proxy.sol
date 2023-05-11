// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";
import "./lib/IUniswapV2Router02.sol";
import "../interfaces/IReserve.sol";

interface CuracaoReserveToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract UniswapV2Proxy is TSOwnable {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Constants and Immutables

    /// @dev 10,000 bps are 100%.
    uint256 private constant BPS = 10_000;

    ERC20 public pairToken;
    IUniswapV2Router02 public exchange;
    IReserve public reserve;
    address public reserveToken;
    uint256 public ceilingMultiplier;
    uint256 public ceilingTradeShare;
    uint256 public floorTradeShare;

    constructor(
        address pairToken_,
        address exchange_,
        address reserve_,
        uint256 ceilingMultiplier_,
        uint256 ceilingTradeShare_,
        uint256 floorTradeShare_
    ) {
        require(pairToken_ != address(0));
        require(exchange_ != address(0));
        require(reserve_ != address(0));
        require(ceilingMultiplier_ != 0);
        require(ceilingTradeShare_ <= BPS);
        require(floorTradeShare_ <= BPS);

        // Set storage.
        pairToken = ERC20(pairToken_);
        exchange = IUniswapV2Router02(exchange_);
        reserve = IReserve(reserve_);
        ceilingMultiplier = ceilingMultiplier_;
        ceilingTradeShare = ceilingTradeShare_;
        floorTradeShare = floorTradeShare_;
        reserveToken = reserve.token();
        require(reserveToken != address(0));
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        (bool breach, bool isFloor) = _checkReserveLimits();

        if (path[0] == reserveToken) {
            // User sells Reserve Token for the Pair Token
            uint256 inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            uint256 outBalanceBefore = pairToken.balanceOf(address(this));

            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), amountIn);
            uint256 thisAmountIn = amountIn;
            uint256 thisAmountOutMin = amountOutMin;

            // Calculate the amount that we will withdraw from the Reserve instead of
            // acquiring it on the exchange
            uint256 withdrawAmount = thisAmountOutMin * floorTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the floor
            // (for ceiling we don't care if a user sells Reserve Tokens since it helps us)
            if (breach && isFloor) {
                // Retrieve the corresponding amount from the Reserve
                reserve.withdrawERC20(address(pairToken), address(this), withdrawAmount);
                thisAmountIn = thisAmountIn * withdrawAmount / thisAmountOutMin;
                thisAmountOutMin = thisAmountOutMin - withdrawAmount;
            }

            // Approve and execute the exchange swap
            ERC20(reserveToken).approve(address(exchange), thisAmountIn);
            amounts = exchange.swapExactTokensForTokens(thisAmountIn, thisAmountOutMin, path, to, deadline);

            // Update the exchange return value with our additional amount
            amounts[amounts.length - 1] = amounts[amounts.length - 1] + withdrawAmount;

            uint256 inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            uint256 outBalanceAfter = pairToken.balanceOf(address(this));

            // Transfer the resulting tokens to the user
            pairToken.transfer(to, outBalanceAfter - outBalanceBefore);

            // Burn the surplus of Reserve Tokens that we didn't see on the exchange
            CuracaoReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
        } else if (path[path.length - 1] == reserveToken) {
            // User buys Reserve Token with the Pair Token
            uint256 balanceBefore = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), amountIn);
            uint256 thisAmountIn = amountIn;
            uint256 thisAmountOutMin = amountOutMin;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint256 mintAmount = amountOutMin * ceilingTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the ceiling
            // (for floor we don't care if a user buys Reserve Tokens since it helps us)
            if (breach && !isFloor) {
                // Mint the corresponding amount from the Reserve
                CuracaoReserveToken(reserveToken).mint(address(this), mintAmount);
                thisAmountIn = thisAmountIn * mintAmount / thisAmountIn;
                thisAmountOutMin = thisAmountOutMin - mintAmount;
            }
            // Approve and execute the exchange swap
            pairToken.approve(address(exchange), thisAmountIn);
            amounts = exchange.swapExactTokensForTokens(thisAmountIn, thisAmountOutMin, path, to, deadline);

            // Update the exchange return value with our additional amount
            amounts[amounts.length - 1] = amounts[amounts.length - 1] + mintAmount;

            uint256 balanceAfter = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the resulting tokens to the user
            ERC20(reserveToken).transfer(to, balanceAfter - balanceBefore);
        }
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        (bool breach, bool isFloor) = _checkReserveLimits();

        if (path[0] == reserveToken) {
            // User sells Reserve Token for the Pair Token
            uint256 inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            uint256 outBalanceBefore = pairToken.balanceOf(address(this));

            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), amountInMax);
            uint256 thisAmountOut = amountOut;
            uint256 thisAmountInMax = amountInMax;

            // Calculate the amount that we will withdraw from the Reserve instead of
            // acquiring it on the exchange
            uint256 withdrawAmount = amountOut * floorTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the floor
            // (for ceiling we don't care if a user sells Reserve Tokens since it helps us)
            if (breach && isFloor) {
                // Retrieve the corresponding amount from the Reserve
                reserve.withdrawERC20(address(pairToken), address(this), withdrawAmount);
                thisAmountInMax = thisAmountInMax * withdrawAmount / thisAmountOut;
                thisAmountOut = thisAmountOut - withdrawAmount;
            }
            // Approve and execute the exchange swap
            ERC20(reserveToken).approve(address(exchange), thisAmountInMax);
            amounts = exchange.swapTokensForExactTokens(thisAmountOut, thisAmountInMax, path, to, deadline);

            // Update the exchange return value with our additional amount
            amounts[amounts.length - 1] = amounts[amounts.length - 1] + withdrawAmount;

            uint256 inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            uint256 outBalanceAfter = pairToken.balanceOf(address(this));

            // Transfer the resulting tokens to the user
            pairToken.transfer(to, outBalanceAfter - outBalanceBefore);

            // Burn the surplus of Reserve Tokens
            CuracaoReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
        } else if (path[path.length - 1] == reserveToken) {
            // User buys Reserve Token with the Pair Token
            uint256 balanceBefore = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), amountInMax);
            uint256 thisAmountOut = amountOut;
            uint256 thisAmountInMax = amountInMax;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint256 mintAmount = thisAmountOut * ceilingTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the ceiling
            // (for floor we don't care if a user buys Reserve Tokens since it helps us)
            if (breach && !isFloor) {
                // Mint the corresponding amount from the Reserve
                CuracaoReserveToken(reserveToken).mint(address(this), mintAmount);
                thisAmountInMax = thisAmountInMax * mintAmount / thisAmountOut;
                thisAmountOut = thisAmountOut - mintAmount;
            }
            // Approve and execute the exchange swap
            pairToken.approve(address(exchange), thisAmountInMax);
            amounts = exchange.swapTokensForExactTokens(thisAmountOut, thisAmountInMax, path, to, deadline);

            // Update the exchange return value with our additional amount
            amounts[amounts.length - 1] = amounts[amounts.length - 1] + mintAmount;

            uint256 balanceAfter = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the resulting tokens to the user
            ERC20(reserveToken).transfer(to, balanceAfter - balanceBefore);
        }
    }

    function _checkReserveLimits() internal returns (bool, bool) {
        (,, uint256 reserveBacking) = reserve.reserveStatus();

        // Floor
        if (reserveBacking <= BPS) {
            return (true, true);
        }

        // Ceiling
        if (reserveBacking >= BPS * ceilingMultiplier) {
            return (true, false);
        }

        return (false, false);
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external view returns (uint256 amountB) {
        return exchange.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        view
        returns (uint256 amountOut)
    {
        return exchange.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        view
        returns (uint256 amountIn)
    {
        return exchange.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        return exchange.getAmountsOut(amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        return exchange.getAmountsIn(amountOut, path);
    }
}
