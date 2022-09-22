pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve} from "../../src/Reserve.sol";
import {ReserveToken} from "../../src/ReserveToken.sol";
import {IReserve} from "../../src/interfaces/IReserve.sol";
import {Treasury} from "../../src/Treasury.sol";
import {Oracle} from "../../src/Oracle.sol";
import {GeoNFT} from "../../src/GeoNFT.sol";

import {ERC20Mock} from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @dev Mints ERC20Mock tokens and approves them to the Reserve.
 *      Registers the ERC20Mock inside the Reserve and lists them as bondable.
 *      Bonds the tokens into the Reserve.
 *      Incurs some debt inside the Reserve.
 */
contract BondAssetsIntoReserve is Script {
    // Note that the addresses are copied from the DEPLOYMENT.md doc file.
    Reserve reserve = Reserve(0x9f4995f6a797Dd932A5301f22cA88104e7e42366);
    Oracle reserveTokenOracle =
        Oracle(0x8684e1f9da7036adFF3D95BA54Db9Ef0F503f5D4);

    Treasury treasury = Treasury(0xEAc68B2e33fA3dbde9bABf3edF17ed3437f3D992);
    Oracle treasuryTokenOracle =
        Oracle(0x07aDaa5739fF6d730CB9D59991072b17a70D9813);

    ERC20Mock token1 = ERC20Mock(0x8E7Af361418CDAb43333c6Bd0fA6906285C0E272);
    ERC20Mock token2 = ERC20Mock(0x57f046C697B15D0933605F12152c5d96cB6f9cc5);
    ERC20Mock token3 = ERC20Mock(0x32dB9295556D2B5193FD404253a4a3fD206B754b);
    GeoNFT geoNFT = GeoNFT(0x3d088f32d7d83FD7868620f76C80604106b74702);
    IReserve.AssetType assetTypeToken1 = IReserve.AssetType.Default;
    IReserve.AssetType assetTypeToken2 = IReserve.AssetType.Stable;
    IReserve.AssetType assetTypeToken3 = IReserve.AssetType.Ecological;
    Oracle token1Oracle = Oracle(0x8e44992e836A742Cdcde08346DB6ECEac86C5C41);
    Oracle token2Oracle = Oracle(0x1A9617212f01846961256717781214F9956512Be);
    Oracle token3Oracle = Oracle(0xBbD9C2bB9901464ef92dbEf3E2DE98b744bA49D5);
    Oracle geoNFT2Oracle = Oracle(0x5dfD0c7d607a08F07F3041a86338404442615127);

    uint token1Amount = 119e18; // 119
    uint token2Amount = 31_000e18; // 31k
    uint token3Amount = 152_500e18; // 152.5k
    uint geoNFT2Price = 43_887_32e16; // $43,887.32

    function run() external {
        vm.startBroadcast();
        {
            geoNFT2Oracle.pushReport(geoNFT2Price);

            // Mint tokens to msg.sender, i.e. the address with which's
            // private key the script is executed.
            token1.mint(msg.sender, token1Amount);
            token2.mint(msg.sender, token2Amount);
            token3.mint(msg.sender, token3Amount);
            geoNFT.mint(msg.sender, 1, 1, "Test GeoNFT #2");

            // Approve tokens to Reserve.
            token1.approve(address(reserve), type(uint).max);
            token2.approve(address(reserve), type(uint).max);
            token3.approve(address(reserve), type(uint).max);
            geoNFT.approve(address(reserve), 2);
            treasury.approve(address(reserve), type(uint).max);

            reserveTokenOracle.pushReport(312e16);
            treasuryTokenOracle.pushReport(1e18);

            // Register token inside the Reserve.
            reserve.registerERC20(
                address(token1),
                address(token1Oracle),
                assetTypeToken1
            );

            reserve.registerERC20(
                address(token2),
                address(token2Oracle),
                assetTypeToken2
            );

            reserve.registerERC20(
                address(token3),
                address(token3Oracle),
                assetTypeToken3
            );

            reserve.registerERC20(
                address(treasury),
                address(treasuryTokenOracle),
                assetTypeToken1
            );
            reserve.registerERC721Id(
                address(geoNFT),
                2,
                address(geoNFT2Oracle)
            );

            // List token as bondable inside the Reserve.
            reserve.listERC20AsBondable(address(token1));
            reserve.listERC20AsBondable(address(token2));
            reserve.listERC20AsBondable(address(token3));
            reserve.listERC20AsBondable(address(treasury));
            reserve.listERC721IdAsBondable(address(geoNFT), 2);

            // Bond tokens into Reserve.
            reserve.bondERC20(address(token1), token1Amount);
            reserve.bondERC20(address(token2), token2Amount);
            reserve.bondERC20(address(token3), token3Amount);
            reserve.bondERC20All(address(treasury));
            reserve.bondERC721Id(address(geoNFT), 2);
            
            // Incur some debt.
            // Note that the token's price is set as 2$.
            // 24% of 2,000$ = 480$.
            // Backing should now be 76%.
            // reserve.incurDebt(480e18);
        }
        vm.stopBroadcast();
    }
}
