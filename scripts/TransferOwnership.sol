pragma solidity 0.8.10;

import "forge-std/Script.sol";

// import {Treasury} from "../src/Treasury.sol";
import {Reserve} from "../src/Reserve.sol";
import {CuracaoReserveToken} from "../src/CuracaoReserveToken.sol";
import {Oracle} from "../src/Oracle.sol";
import {KolektivoGuilder} from "../src/mento/KolektivoGuilder.sol";
import {CuracaoReserveToken} from "../src/CuracaoReserveToken.sol";
import {Exchange} from "../src/mento/MentoExchange.sol";
import {MentoReserve} from "../src/mento/MentoReserve.sol";
import {Registry} from "../src/mento/MentoRegistry.sol";
import {Freezer} from "../src/mento/lib/Freezer.sol";
import {SortedOracles} from "../src/mento/SortedOracles.sol";

/**
 * @title Treasury Deployment Script
 *
 * @dev Script to deploy a new treasury and initiating an owner switch from the
 *      deployer address to another address given via environment variable.
 *
 *      The following environment variables MUST be provided:
 *      - TRUSTED_OWNER
 */
contract TransferOwnership is Script {
    Exchange exchange;
    Registry registry;
    MentoReserve mentoReserve;
    KolektivoGuilder kolektivoGuilder;
    Freezer freezer;
    SortedOracles sortedOracles;
    Reserve reserve;
    CuracaoReserveToken reserveToken;

    function run() external {
        // Treasury treasury = Treasury(vm.envAddress("DEPLOYMENT_TREASURY"));
        // Oracle treasuryOracle = Oracle(vm.envAddress("DEPLOYMENT_TREASURY_TOKEN_ORACLE"));
        reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        reserveToken = CuracaoReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        exchange = Exchange(vm.envAddress("DEPLOYMENT_MENTO_EXCHANGE"));
        mentoReserve = MentoReserve(vm.envAddress("DEPLOYMENT_MENTO_RESERVE"));
        kolektivoGuilder = KolektivoGuilder(vm.envAddress("DEPLOYMENT_MENTO_KOLEKTIVO_GUILDER"));
        freezer = Freezer(vm.envAddress("DEPLOYMENT_MENTO_FREEZER"));
        registry = Registry(vm.envAddress("DEPLOYMENT_MENTO_REGISTRY"));
        sortedOracles = SortedOracles(vm.envAddress("DEPLOYMENT_MENTO_SORTED_ORACLES"));

        // Oracle cUSDOracle = Oracle(vm.envAddress("DEPLOYMENT_ORACLE_CUSD"));
        Oracle reserveOracle = Oracle(vm.envAddress("DEPLOYMENT_ORACLE_KCUR"));
        // Oracle erc20Mock1Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"));
        // Oracle erc20Mock2Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"));
        // Oracle erc20Mock3Oracle = Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"));
        // Oracle geoNFT1Oracle = Oracle(vm.envAddress("DEPLOYMENT_GEO_NFT_1_ORACLE"));
        // Oracle geoNFT2Oracle = Oracle(vm.envAddress("DEPLOYMENT_GEO_NFT_2_ORACLE"));

        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("KOLEKTIVO_MULTISIG");
        require(newOwner != address(0), "DeployTreasury: Missing env variable: trusted owner");

        // Initiate owner switch.
        vm.startBroadcast();
        {
            // Kolektivo contract
            reserve.setPendingOwner(newOwner);
            reserveToken.setPendingOwner(newOwner);
            // Mento
            exchange.transferOwnership(newOwner);
            mentoReserve.transferOwnership(newOwner);
            sortedOracles.transferOwnership(newOwner);
            kolektivoGuilder.transferOwnership(newOwner);
            freezer.transferOwnership(newOwner);
            registry.transferOwnership(newOwner);

            // treasury.setPendingOwner(newOwner);
            // treasuryOracle.setPendingOwner(newOwner);
            // reserveOracle.setPendingOwner(newOwner);
            // cUSDOracle.setPendingOwner(newOwner);
            // erc20Mock1Oracle.setPendingOwner(newOwner);
            // erc20Mock2Oracle.setPendingOwner(newOwner);
            // erc20Mock3Oracle.setPendingOwner(newOwner);
            // geoNFT1Oracle.setPendingOwner(newOwner);
            // geoNFT2Oracle.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(reserve.pendingOwner() == newOwner, "DeployTreasury: Initiating owner switch failed");

        // Log successful initiation of the owner switch.
        console2.log("Owner switch succesfully initiated to address", newOwner);

        // Print addresses for the multi-sig ownership transfer
        console2.log("List of addresses for the multi-sig to accept ownership in: ");
        // console2.log("- ", vm.envAddress("DEPLOYMENT_TREASURY"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_RESERVE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MENTO_EXCHANGE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MENTO_RESERVE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MENTO_KOLEKTIVO_GUILDER"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MENTO_FREEZER"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MENTO_REGISTRY"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MENTO_SORTED_ORACLES"));

        // console2.log("- ", vm.envAddress("DEPLOYMENT_TREASURY_TOKEN_ORACLE"));
        // console2.log("- ", vm.envAddress("DEPLOYMENT_ORACLE_KCUR"));
        // console2.log("- ", vm.envAddress("DEPLOYMENT_ORACLE_CUSD"));
        // console2.log("- ", vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"));
        // console2.log("- ", vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"));
        // console2.log("- ", vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"));
        // console2.log("- ", vm.envAddress("DEPLOYMENT_GEO_NFT_1_ORACLE"));
        // console2.log("- ", vm.envAddress("DEPLOYMENT_GEO_NFT_2_ORACLE"));
    }
}
