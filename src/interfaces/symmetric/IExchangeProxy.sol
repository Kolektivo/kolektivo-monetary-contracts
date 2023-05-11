// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface PoolInterface {
    function swapExactAmountIn(address, uint256, address, uint256, uint256) external returns (uint256, uint256);
    function swapExactAmountOut(address, uint256, address, uint256, uint256) external returns (uint256, uint256);
    function calcInGivenOut(uint256, uint256, uint256, uint256, uint256, uint256) external pure returns (uint256);
    function calcOutGivenIn(uint256, uint256, uint256, uint256, uint256, uint256) external pure returns (uint256);
    function getDenormalizedWeight(address) external view returns (uint256);
    function getBalance(address) external view returns (uint256);
    function getSwapFee() external view returns (uint256);
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

interface RegistryInterface {
    function getBestPoolsWithLimit(address, address, uint256) external view returns (address[] memory);
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

    function setRegistry(address _registry) external;

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

    function viewSplitExactIn(address tokenIn, address tokenOut, uint256 swapAmount, uint256 nPools)
        external
        view
        returns (Swap[] memory swaps, uint256 totalOutput);

    function viewSplitExactOut(address tokenIn, address tokenOut, uint256 swapAmount, uint256 nPools)
        external
        view
        returns (Swap[] memory swaps, uint256 totalOutput);
}
