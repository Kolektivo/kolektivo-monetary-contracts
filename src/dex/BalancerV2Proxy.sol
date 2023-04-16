// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {TSOwnable} from "solrocket/TSOwnable.sol";
import "./lib/IUniswapV2Router02.sol";
import "../interfaces/IReserve.sol";

interface ReserveToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

interface TokenInterface {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface ExchangeProxy {
    struct Pool {
        address pool;
        uint256 tokenBalanceIn;
        uint256 tokenWeightIn;
        uint256 tokenBalanceOut;
        uint256 tokenWeightOut;
        uint256 swapFee;
        uint256 effectiveLiquidity;
    }

    struct Swap {
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 swapAmount; // tokenInAmount / tokenOutAmount
        uint256 limitReturnAmount; // minAmountOut / maxAmountIn
        uint256 maxPrice;
    }

    function batchSwapExactIn(
        Swap[] memory swaps,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 totalAmountIn,
        uint256 minTotalAmountOut
    ) external payable returns (uint256 totalAmountOut);

    function batchSwapExactOut(
        Swap[] memory swaps,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 maxTotalAmountIn
    ) external payable returns (uint256 totalAmountIn);

    function multihopBatchSwapExactIn(
        Swap[][] memory swapSequences,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 totalAmountIn,
        uint256 minTotalAmountOut
    ) external payable returns (uint256 totalAmountOut);

    function multihopBatchSwapExactOut(
        Swap[][] memory swapSequences,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 maxTotalAmountIn
    ) external payable returns (uint256 totalAmountIn);

    function smartSwapExactIn(
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 totalAmountIn,
        uint256 minTotalAmountOut,
        uint256 nPools
    ) external payable returns (uint256 totalAmountOut);

    function smartSwapExactOut(
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 totalAmountOut,
        uint256 maxTotalAmountIn,
        uint256 nPools
    ) external payable returns (uint256 totalAmountIn);

    function viewSplitExactIn(address tokenIn, address tokenOut, uint256 swapAmount, uint256 nPools)
        external
        view
        returns (Swap[] memory swaps, uint256 totalOutput);

    function viewSplitExactOut(address tokenIn, address tokenOut, uint256 swapAmount, uint256 nPools)
        external
        view
        returns (Swap[] memory swaps, uint256 totalOutput);
}

contract BalancerV2Proxy is TSOwnable {
    using SafeTransferLib for ERC20;

    //--------------------------------------------------------------------------
    // Constants and Immutables

    /// @dev 10,000 bps are 100%.
    uint256 private constant BPS = 10_000;

    ERC20 public pairToken;
    ExchangeProxy public exchange;
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
        exchange = ExchangeProxy(exchange_);
        reserve = IReserve(reserve_);
        ceilingMultiplier = ceilingMultiplier_;
        ceilingTradeShare = ceilingTradeShare_;
        floorTradeShare = floorTradeShare_;
        reserveToken = reserve.token();
        require(reserveToken != address(0));
    }

    function batchSwapExactIn(
        ExchangeProxy.Swap[] memory swaps,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 totalAmountIn,
        uint256 minTotalAmountOut
    ) external payable returns (uint256 totalAmountOut) {
        (bool breach, bool isFloor) = _checkReserveLimits();
        require(
            (address(tokenIn) == reserveToken && address(tokenOut) == address(pairToken)) || (address(tokenIn) == address(pairToken) && address(tokenOut) == reserveToken)
        );
        require(swaps.length == 1);

        if (address(tokenIn) == reserveToken) {
            // User sells Reserve Token for the Pair Token
            uint256 inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            uint256 outBalanceBefore = pairToken.balanceOf(address(this));

            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), totalAmountIn);
            uint256 thisAmountIn = totalAmountIn;
            uint256 thisAmountOutMin = minTotalAmountOut;

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

                swaps[0].swapAmount = thisAmountIn / thisAmountOutMin;
                swaps[0].limitReturnAmount = thisAmountOutMin / thisAmountIn;
            }

            // Approve and execute the exchange swap
            ERC20(reserveToken).approve(address(exchange), thisAmountIn);
            uint256 outAmount = exchange.batchSwapExactIn(swaps, tokenIn, tokenOut, thisAmountIn, thisAmountOutMin);

            // Update the exchange return value with our additional amount
            outAmount += withdrawAmount;
            require(outAmount >= minTotalAmountOut);

            uint256 inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            uint256 outBalanceAfter = pairToken.balanceOf(address(this));

            // Transfer the resulting tokens to the user
            pairToken.transfer(msg.sender, outBalanceAfter - outBalanceBefore);

            // Burn the surplus of Reserve Tokens that we didn't see on the exchange
            ReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
        } else if (address(tokenOut) == reserveToken) {
            // User buys Reserve Token with the Pair Token
            uint256 balanceBefore = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), totalAmountIn);
            uint256 thisAmountIn = totalAmountIn;
            uint256 thisAmountOutMin = minTotalAmountOut;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint256 mintAmount = thisAmountOutMin * ceilingTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the ceiling
            // (for floor we don't care if a user buys Reserve Tokens since it helps us)
            if (breach && !isFloor) {
                // Mint the corresponding amount from the Reserve
                ReserveToken(reserveToken).mint(address(this), mintAmount);
                thisAmountIn = thisAmountIn * mintAmount / thisAmountIn;
                thisAmountOutMin = thisAmountOutMin - mintAmount;

                swaps[0].swapAmount = thisAmountIn / thisAmountOutMin;
                swaps[0].limitReturnAmount = thisAmountOutMin / thisAmountIn;
            }
            // Approve and execute the exchange swap
            pairToken.approve(address(exchange), thisAmountIn);
            uint256 outAmount = exchange.batchSwapExactIn(swaps, tokenIn, tokenOut, thisAmountIn, thisAmountOutMin);

            // Update the exchange return value with our additional amount
            outAmount += mintAmount;
            require(outAmount >= minTotalAmountOut);

            uint256 balanceAfter = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the resulting tokens to the user
            ERC20(reserveToken).transfer(msg.sender, balanceAfter - balanceBefore);
        }
    }

    function batchSwapExactOut(
        ExchangeProxy.Swap[] memory swaps,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 maxTotalAmountIn
    ) external payable returns (uint256 totalAmountIn) {
        (bool breach, bool isFloor) = _checkReserveLimits();
        require(
            (address(tokenIn) == reserveToken && address(tokenOut) == address(pairToken)) || (address(tokenIn) == address(pairToken) && address(tokenOut) == reserveToken)
        );
        require(swaps.length == 1);

        if (address(tokenIn) == reserveToken) {
            // User sells Reserve Token for the Pair Token
            uint256 inBalanceBefore = ERC20(reserveToken).balanceOf(address(this));
            uint256 outBalanceBefore = pairToken.balanceOf(address(this));

            // Transfer the Reserve Token to us
            ERC20(reserveToken).safeTransferFrom(msg.sender, address(this), maxTotalAmountIn);
            uint256 thisAmountOut = swaps[0].limitReturnAmount * maxTotalAmountIn;
            uint256 thisAmountInMax = maxTotalAmountIn;

            // Calculate the amount that we will withdraw from the Reserve instead of
            // acquiring it on the exchange
            uint256 withdrawAmount = thisAmountOut * floorTradeShare / BPS;

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
            exchange.batchSwapExactOut(swaps, tokenIn, tokenOut, maxTotalAmountIn);

            uint256 inBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            uint256 inAmount = inBalanceAfter - inBalanceBefore;
            uint256 outBalanceAfter = pairToken.balanceOf(address(this));
            uint256 outAmount = outBalanceAfter - outBalanceBefore + withdrawAmount;
            require(inAmount <= maxTotalAmountIn && outAmount >= thisAmountOut);

            // Transfer the resulting tokens to the user
            pairToken.transfer(msg.sender, outBalanceAfter - outBalanceBefore);

            // Burn the surplus of Reserve Tokens
            ReserveToken(reserveToken).burn(address(this), inBalanceAfter - inBalanceBefore);
        } else if (address(tokenOut) == reserveToken) {
            // User buys Reserve Token with the Pair Token
            uint256 inBalanceBefore = pairToken.balanceOf(address(this));
            uint256 outBalanceBefore = ERC20(reserveToken).balanceOf(address(this));

            // Transfer the Pair Token to us
            pairToken.safeTransferFrom(msg.sender, address(this), maxTotalAmountIn);
            uint256 thisAmountOut = swaps[0].limitReturnAmount * maxTotalAmountIn;
            uint256 thisAmountInMax = maxTotalAmountIn;

            // Calculate the amount that we will mint from the Reserve instead of
            // acquiring it on the exchange
            uint256 mintAmount = thisAmountOut * ceilingTradeShare / BPS;

            // If a limit is breached in the Reserve and it is the ceiling
            // (for floor we don't care if a user buys Reserve Tokens since it helps us)
            if (breach && !isFloor) {
                // Mint the corresponding amount from the Reserve
                ReserveToken(reserveToken).mint(address(this), mintAmount);
                thisAmountInMax = thisAmountInMax * mintAmount / thisAmountOut;
                thisAmountOut = thisAmountOut - mintAmount;
            }
            // Approve and execute the exchange swap
            pairToken.approve(address(exchange), thisAmountInMax);
            exchange.batchSwapExactOut(swaps, tokenIn, tokenOut, maxTotalAmountIn);

            uint256 inBalanceAfter = pairToken.balanceOf(address(this));
            uint256 inAmount = inBalanceBefore - inBalanceAfter;
            uint256 outBalanceAfter = ERC20(reserveToken).balanceOf(address(this));
            uint256 outAmount = outBalanceAfter - outBalanceBefore + mintAmount;
            require(inAmount <= maxTotalAmountIn && outAmount >= thisAmountOut);

            // Transfer the resulting tokens to the user
            ERC20(reserveToken).transfer(msg.sender, outAmount);
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
}
