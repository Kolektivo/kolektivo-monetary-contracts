// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";
import "./lib/IUniswapV2Router02.sol";
import "../interfaces/IReserve.sol";

interface ReserveToken {
    function mint(address to, uint amount) external;
    function burn(address from, uint amount) external;
}
contract UniswapV2Proxy is TSOwnable {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Constants and Immutables

    /// @dev 10,000 bps are 100%.
    uint private constant BPS = 10_000;

    ERC20 public pairToken;
    IUniswapV2Router02 public exchange;
    IReserve public reserve;
    address public reserveToken;
    uint public ceilingMultiplier;
    uint public ceilingTradeShare;
    uint public floorTradeShare;

    constructor(
        address pairToken_,
        address exchange_,
        address reserve_,
        uint ceilingMultiplier_,
        uint ceilingTradeShare_,
        uint floorTradeShare_
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
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        (bool breach, bool isFloor) = _checkReserveLimits();
    
        if(path[0] == reserveToken) { 
            // User sells Reserve Token for the Pair Token
            uint inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            uint outBalanceBefore = pairToken.balanceOf(address(this));
            
            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), amountIn);
            uint thisAmountIn = amountIn;
            uint thisAmountOutMin = amountOutMin;

            // Calculate the amount that we will withdraw from the Reserve instead of
            // acquiring it on the exchange
            uint withdrawAmount = thisAmountOutMin * floorTradeShare / BPS;
            
            // If a limit is breached in the Reserve and it is the floor
            // (for ceiling we don't care if a user sells Reserve Tokens since it helps us)
            if(breach && isFloor) {
                // Retrieve the corresponding amount from the Reserve
                reserve.withdrawERC20(address(pairToken), address(this), withdrawAmount);
                thisAmountIn = thisAmountIn * withdrawAmount / thisAmountOutMin;
                thisAmountOutMin = thisAmountOutMin - withdrawAmount;
            }

            // Approve and execute the exchange swap
            ERC20(reserveToken).approve(address(exchange), thisAmountIn);
            amounts = exchange.swapExactTokensForTokens(thisAmountIn, thisAmountOutMin, path, to, deadline);
            
            // Update the exchange return value with our additional amount
            amounts[amounts.length-1] = amounts[amounts.length-1] + withdrawAmount;

            uint inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            uint outBalanceAfter = pairToken.balanceOf(address(this));

            // Transfer the resulting tokens to the user
            pairToken.transfer(to, outBalanceAfter - outBalanceBefore);
            
            // Burn the surplus of Reserve Tokens that we didn't see on the exchange
            ReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
        } else if(path[path.length-1] == reserveToken) {
            // User buys Reserve Token with the Pair Token
            uint balanceBefore = ERC20(reserveToken).balanceOf(address(this));
                        
            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), amountIn);
            uint thisAmountIn = amountIn;
            uint thisAmountOutMin = amountOutMin;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint mintAmount = amountOutMin * ceilingTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the ceiling
            // (for floor we don't care if a user buys Reserve Tokens since it helps us)
            if(breach && !isFloor) {
                // Mint the corresponding amount from the Reserve
                ReserveToken(reserveToken).mint(address(this), mintAmount);
                thisAmountIn = thisAmountIn * mintAmount / thisAmountIn;
                thisAmountOutMin = thisAmountOutMin - mintAmount;
            }
            // Approve and execute the exchange swap
            pairToken.approve(address(exchange), thisAmountIn);
            amounts = exchange.swapExactTokensForTokens(thisAmountIn, thisAmountOutMin, path, to, deadline);

            // Update the exchange return value with our additional amount
            amounts[amounts.length-1] = amounts[amounts.length-1] + mintAmount;

            uint balanceAfter = ERC20(reserveToken).balanceOf(address(this));
             
            // Transfer the resulting tokens to the user
            ERC20(reserveToken).transfer(to, balanceAfter - balanceBefore);
        }
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        (bool breach, bool isFloor) = _checkReserveLimits();
    
        if(path[0] == reserveToken) {
            // User sells Reserve Token for the Pair Token
            uint inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            uint outBalanceBefore = pairToken.balanceOf(address(this));

            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), amountInMax);
            uint thisAmountOut = amountOut;
            uint thisAmountInMax = amountInMax;

            // Calculate the amount that we will withdraw from the Reserve instead of
            // acquiring it on the exchange
            uint withdrawAmount = amountOut * floorTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the floor
            // (for ceiling we don't care if a user sells Reserve Tokens since it helps us)
            if(breach && isFloor) {
                // Retrieve the corresponding amount from the Reserve
                reserve.withdrawERC20(address(pairToken), address(this), withdrawAmount);
                thisAmountInMax = thisAmountInMax * withdrawAmount / thisAmountOut;
                thisAmountOut = thisAmountOut - withdrawAmount;
            }
            // Approve and execute the exchange swap
            ERC20(reserveToken).approve(address(exchange), thisAmountInMax);
            amounts = exchange.swapTokensForExactTokens(thisAmountOut, thisAmountInMax, path, to, deadline);

            // Update the exchange return value with our additional amount
            amounts[amounts.length-1] = amounts[amounts.length-1] + withdrawAmount;

            uint inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            uint outBalanceAfter = pairToken.balanceOf(address(this));
            
            // Transfer the resulting tokens to the user
            pairToken.transfer(to, outBalanceBefore - outBalanceAfter);

            // Burn the surplus of Reserve Tokens
            ReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
        } else if(path[path.length-1] == reserveToken) {
            // User buys Reserve Token with the Pair Token
            uint balanceBefore = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), amountInMax);
            uint thisAmountOut = amountOut;
            uint thisAmountInMax = amountInMax;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint mintAmount = thisAmountOut * ceilingTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the ceiling
            // (for floor we don't care if a user buys Reserve Tokens since it helps us)
            if(breach && !isFloor) {
                // Mint the corresponding amount from the Reserve
                ReserveToken(reserveToken).mint(address(this), mintAmount);
                thisAmountInMax = thisAmountInMax * mintAmount / thisAmountOut;
                thisAmountOut = thisAmountOut - mintAmount;
            }
            // Approve and execute the exchange swap
            pairToken.approve(address(exchange), thisAmountInMax);
            amounts = exchange.swapTokensForExactTokens(thisAmountOut, thisAmountInMax, path, to, deadline);
            
            // Update the exchange return value with our additional amount
            amounts[amounts.length-1] = amounts[amounts.length-1] + mintAmount;

            uint balanceAfter = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the resulting tokens to the user
            ERC20(reserveToken).transfer(to, balanceBefore - balanceAfter);
        }
    }

    function _checkReserveLimits() internal returns (bool, bool) {

        ( , , uint reserveBacking) = reserve.reserveStatus();

        // Floor
        if(reserveBacking <= BPS) {
            return (true, true);
        }
        
        // Ceiling
        if(reserveBacking >= BPS * ceilingMultiplier) {
            return(true, false);
        }

        return (false, false);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) external view returns (uint amountB) {
        return exchange.quote(amountA, reserveA, reserveB); 
    }
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external view returns (uint amountOut) {
        return exchange.getAmountOut(amountIn, reserveIn, reserveOut); 
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external view returns (uint amountIn) {
        return exchange.getAmountIn(amountOut, reserveIn, reserveOut); 
    }

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts) {
        return exchange.getAmountsOut(amountIn, path); 
    }

    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts) {
        return exchange.getAmountsIn(amountOut, path); 
    }
}