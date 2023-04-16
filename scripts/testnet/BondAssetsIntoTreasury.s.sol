pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Treasury} from "../../src/Treasury.sol";
import {Oracle} from "../../src/Oracle.sol";
import {GeoNFT} from "../../src/GeoNFT.sol";
import {ERC20Mock} from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @dev Initializes the ERC20Mock token oracle with some price and mints some
 *      ERC20Mock tokens. Aftwards the ERC20Mock is registered inside the
 *      Treasury, approved to be spent by the Treasury and then bonded into
 *      the Treasury.
 *
 *      The ERC20Mock token's price is set to a new value and a Treasury rebase
 *      triggered manually.
 */
contract BondAssetsIntoTreasury is Script {
    Treasury treasury;
    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;
    GeoNFT geoNFT;
    Treasury.AssetType assetTypeToken1 = Treasury.AssetType.Default;
    Treasury.AssetType assetTypeToken2 = Treasury.AssetType.Stable;
    Treasury.AssetType assetTypeToken3 = Treasury.AssetType.Ecological;
    Treasury.RiskLevel riskLevelToken1 = Treasury.RiskLevel.Low;
    Treasury.RiskLevel riskLevelToken2 = Treasury.RiskLevel.Medium;
    Treasury.RiskLevel riskLevelToken3 = Treasury.RiskLevel.High;
    Oracle token1Oracle;
    Oracle token2Oracle;
    Oracle token3Oracle;
    Oracle geoNFT1Oracle;
    uint token1Amount;
    uint token2Amount;
    uint token3Amount;
    uint token1Price;
    uint token2Price;
    uint token3Price;
    uint geoNFT1Price;
    
    function run() external {
        treasury = Treasury(vm.envAddress("DEPLOYMENT_TREASURY"));
        token1 = ERC20Mock(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1"));
        token2 = ERC20Mock(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2"));
        token3 = ERC20Mock(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3"));
        geoNFT = GeoNFT(vm.envAddress("DEPLOYMENT_GEO_NFT_1"));

        token1Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"));
        token2Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"));
        token3Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"));
        geoNFT1Oracle = Oracle(vm.envAddress("DEPLOYMENT_GEO_NFT_1_ORACLE"));

        token1Amount = vm.envUint("DEPLOYMENT_TOKEN_1_AMOUNT_TREASURY");
        token2Amount = vm.envUint("DEPLOYMENT_TOKEN_2_AMOUNT_TREASURY");
        token3Amount = vm.envUint("DEPLOYMENT_TOKEN_3_AMOUNT_TREASURY");

        token1Price = vm.envUint("DEPLOYMENT_TOKEN_1_PRICE_TREASURY");
        token2Price = vm.envUint("DEPLOYMENT_TOKEN_2_PRICE_TREASURY");
        token3Price = vm.envUint("DEPLOYMENT_TOKEN_3_PRICE_TREASURY");
        geoNFT1Price = vm.envUint("DEPLOYMENT_GEO_NFT_1_PRICE_TREASURY");

        vm.startBroadcast();
        {
            // Set initial token prices
            token1Oracle.pushReport(token1Price);
            token2Oracle.pushReport(token2Price);
            token3Oracle.pushReport(token3Price);
            geoNFT1Oracle.pushReport(geoNFT1Price);

            // Mint tokens to msg.sender, i.e. the address with which's
            // private key the script is executed.
            token1.mint(vm.envAddress("WALLET_DEPLOYER"), token1Amount);
            token2.mint(vm.envAddress("WALLET_DEPLOYER"), token2Amount);
            token3.mint(vm.envAddress("WALLET_DEPLOYER"), token3Amount);
            geoNFT.mint(vm.envAddress("WALLET_DEPLOYER"), 1, 1, "Test GeoNFT #1");

            // Approve tokens to Treasury.
            token1.approve(address(treasury), type(uint).max);
            token2.approve(address(treasury), type(uint).max);
            token3.approve(address(treasury), type(uint).max);
            geoNFT.approve(address(treasury), 1);

            // Register token inside the Treasury.
            treasury.registerERC20(
                address(token1),
                address(token1Oracle),
                assetTypeToken1,
                riskLevelToken1
            );
            treasury.registerERC20(
                address(token2),
                address(token2Oracle),
                assetTypeToken2,
                riskLevelToken2
            );
            treasury.registerERC20(
                address(token3),
                address(token3Oracle),
                assetTypeToken3,
                riskLevelToken3
            );
            treasury.registerERC721Id(
                address(geoNFT),
                1,
                address(geoNFT1Oracle)
            );

            // List token as bondable inside the Treasury.
            treasury.listERC20AsBondable(address(token1));
            treasury.listERC20AsBondable(address(token2));
            treasury.listERC20AsBondable(address(token3));
            treasury.listERC721IdAsBondable(address(geoNFT), 1);

            // Bond tokens into Treasury.
            treasury.bondERC20(address(token1), token1Amount);
            treasury.bondERC20(address(token2), token2Amount);
            treasury.bondERC20(address(token3), token3Amount);
            treasury.bondERC721Id(address(geoNFT), 1);
        }
        vm.stopBroadcast();

        // Check balances.
        require(
            treasury.balanceOf(vm.envAddress("WALLET_DEPLOYER")) ==
                (token1Price * token1Amount) /
                    1e18 +
                    (token2Price * token2Amount) /
                    1e18 +
                    (token3Price * token3Amount) /
                    1e18 + 
                    geoNFT1Price,
            "BondAssetsIntoTreasury: Invalid amount of treasury tokens received through bonding"
        );
        require(
            token1.balanceOf(address(treasury)) == token1Amount,
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );
        require(
            token2.balanceOf(address(treasury)) == token2Amount,
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );
        require(
            token3.balanceOf(address(treasury)) == token3Amount,
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );
        require(
            geoNFT.ownerOf(1) == address(treasury), 
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );

        vm.startBroadcast();
        {
            // Change token's price
            token1Oracle.purgeReports();
            token1Oracle.pushReport(token1Price / 2);

            // Trigger a Treasury rebase.
            treasury.rebase();
        }
        vm.stopBroadcast();

        // Check balance.
        require(
            treasury.balanceOf(vm.envAddress("WALLET_DEPLOYER")) ==
                ((token1Price / 2) * token1Amount) /
                    1e18 +
                    (token2Price * token2Amount) /
                    1e18 +
                    (token3Price * token3Amount) /
                    1e18 +
                    geoNFT1Price,
            "BondAssetsIntoTreasury: Invalid amount of treasury tokens after rebase"
        );
    }
}
