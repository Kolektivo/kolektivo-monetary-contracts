pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve} from "../../src/Reserve.sol";
import {CuracaoReserveToken} from "../../src/CuracaoReserveToken.sol";
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
    Reserve reserve;
    CuracaoReserveToken reserveToken;
    Oracle reserveTokenOracle;
    Treasury treasury;
    Oracle treasuryTokenOracle;
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;
    GeoNFT geoNFT;
    IReserve.AssetType assetTypeToken1 = IReserve.AssetType.Default;
    IReserve.AssetType assetTypeToken2 = IReserve.AssetType.Stable;
    IReserve.AssetType assetTypeToken3 = IReserve.AssetType.Ecological;
    IReserve.RiskLevel riskLevelToken1 = IReserve.RiskLevel.Low;
    IReserve.RiskLevel riskLevelToken2 = IReserve.RiskLevel.Medium;
    IReserve.RiskLevel riskLevelToken3 = IReserve.RiskLevel.High;
    Oracle token1Oracle;
    Oracle token2Oracle;
    Oracle token3Oracle;
    Oracle geoNFT2Oracle;

    uint256 token1Amount;
    uint256 token2Amount;
    uint256 token3Amount;
    uint256 geoNFT2Price;

    function run() external {
        reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        reserveToken = CuracaoReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        reserveTokenOracle = Oracle(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN_ORACLE"));

        treasury = Treasury(vm.envAddress("DEPLOYMENT_TREASURY"));
        treasuryTokenOracle = Oracle(vm.envAddress("DEPLOYMENT_TREASURY_TOKEN_ORACLE"));

        token1 = ERC20Mock(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1"));
        token2 = ERC20Mock(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2"));
        token3 = ERC20Mock(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3"));
        geoNFT = GeoNFT(vm.envAddress("DEPLOYMENT_GEO_NFT_1"));

        token1Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"));
        token2Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"));
        token3Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"));
        geoNFT2Oracle = Oracle(vm.envAddress("DEPLOYMENT_GEO_NFT_2_ORACLE"));

        token1Amount = vm.envUint("DEPLOYMENT_TOKEN_1_AMOUNT_RESERVE");
        token2Amount = vm.envUint("DEPLOYMENT_TOKEN_2_AMOUNT_RESERVE");
        token3Amount = vm.envUint("DEPLOYMENT_TOKEN_3_AMOUNT_RESERVE");
        geoNFT2Price = vm.envUint("DEPLOYMENT_GEO_NFT_2_PRICE_RESERVE");

        vm.startBroadcast();
        {
            geoNFT2Oracle.pushReport(geoNFT2Price);

            // Mint tokens to vm.envAddress("WALLET_DEPLOYER"), i.e. the address with which's
            // private key the script is executed.
            token1.mint(vm.envAddress("WALLET_DEPLOYER"), token1Amount);
            token2.mint(vm.envAddress("WALLET_DEPLOYER"), token2Amount);
            token3.mint(vm.envAddress("WALLET_DEPLOYER"), token3Amount);
            geoNFT.mint(vm.envAddress("WALLET_DEPLOYER"), 1, 1, "Test GeoNFT #2");

            // Approve tokens to Reserve.
            token1.approve(address(reserve), type(uint256).max);
            token2.approve(address(reserve), type(uint256).max);
            token3.approve(address(reserve), type(uint256).max);
            geoNFT.approve(address(reserve), 2);
            treasury.approve(address(reserve), type(uint256).max);

            reserveTokenOracle.pushReport(vm.envUint("DEPLOYMENT_RESERVE_TOKEN_PRICE"));
            treasuryTokenOracle.pushReport(vm.envUint("DEPLOYMENT_TREASURY_TOKEN_PRICE"));

            // Register token inside the Reserve.
            reserve.registerERC20(address(token1), address(token1Oracle), assetTypeToken1, riskLevelToken1);

            reserve.registerERC20(address(token2), address(token2Oracle), assetTypeToken2, riskLevelToken2);

            reserve.registerERC20(address(token3), address(token3Oracle), assetTypeToken3, riskLevelToken3);

            reserve.registerERC20(address(treasury), address(treasuryTokenOracle), assetTypeToken1, riskLevelToken1);
            reserve.registerERC721Id(address(geoNFT), 2, address(geoNFT2Oracle));

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

            // Send kCUR to Reserve (just to store them there)
            reserveToken.transfer(address(reserve), reserveToken.balanceOf(vm.envAddress("WALLET_DEPLOYER")));
        }
        vm.stopBroadcast();
    }
}
