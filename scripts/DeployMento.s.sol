pragma solidity 0.8.10;

import "forge-std/Script.sol";

import "@oz/token/ERC20/ERC20.sol";

import {StableTokenKG} from "../src/mento/StableTokenKG.sol";
import {Exchange} from "../src/mento/MentoExchange.sol";
import {MentoReserve} from "../src/mento/MentoReserve.sol";
import {Registry} from "../src/mento/MentoRegistry.sol";
import {Freezer} from "../src/mento/lib/Freezer.sol";
import {FixidityLib} from "../src/mento/lib/FixidityLib.sol";

/**
 * @title Mento Deployment Script
 *
 * @dev Script to deploy a new Mento system and initialize the system.
 *
 */
contract DeployMento is Script {
    using FixidityLib for FixidityLib.Fraction;

    Exchange exchange;
    Registry registry;
    MentoReserve reserve;
    StableTokenKG token;
    Freezer freezer;

    function run() external {
        // Read deployment settings from environment variables.
        address reserveToken = vm.envAddress("DEPLOYMENT_RESERVE_TOKEN");
        string memory reserveTokenSymbol = ERC20(reserveToken).symbol();

        string memory tokenName = vm.envString("DEPLOYMENT_MENTO_TOKEN_NAME");
        string memory tokenSymbol = vm.envString("DEPLOYMENT_MENTO_TOKEN_SYMBOL");
        // Check settings.
        require(
            reserveToken != address(0),
            "DeployMento: Missing env variable: token"
        );

        // Deploy the Reserve.
        vm.startBroadcast();
        {
            freezer = new Freezer();
            freezer.initialize();

            registry = new Registry();
            registry.initialize();

            token = new StableTokenKG();
            token.initialize(
                tokenName, // _name
                tokenSymbol, // _symbol
                18, // _decimals
                address(registry), // registryAddress
                FixidityLib.newFixed(1).unwrap(), // inflationRate
                1 * 365 * 24 * 60 * 60, // inflationFactorUpdatePeriod
                tokenSymbol // exchangeIdentifier
            );

            bytes32[] memory assetAllocationSymbols = new bytes32[](1);
            assetAllocationSymbols[0] = bytes32(bytes(reserveTokenSymbol));
            uint256[] memory assetAllocationWeights = new uint256[](1);
            assetAllocationWeights[0] = FixidityLib.newFixed(1).unwrap(); // 100%

            reserve = new MentoReserve();
            reserve.initialize(
                address(registry),
                24 hours, // _tobinTaxStalenessThreshold
                FixidityLib.newFixed(1).unwrap(), // _spendingRatio
                0, // _frozenGold
                0, // _frozenDays
                assetAllocationSymbols, // _assetAllocationSymbols
                assetAllocationWeights, // _assetAllocationWeights
                0, // _tobinTax
                FixidityLib.newFixed(1).unwrap() // _tobinTaxReserveRatio
            );
            
            exchange = new Exchange();
            exchange.initialize(
                address(registry), // registryAddress
                tokenSymbol, // stableTokenIdentifier
                FixidityLib.newFixedFraction(3, 1000).unwrap(), // _spread
                FixidityLib.newFixedFraction(1, 2).unwrap(), // _reserveFraction
                60 * 60, // _updateFrequency
                1 // _minimumReports
            );

            registry.setAddressFor("Freezer", address(freezer));
            registry.setAddressFor("GoldToken", reserveToken);
            registry.setAddressFor("Reserve", address(reserve));
            registry.setAddressFor(tokenSymbol, address(token));
            registry.setAddressFor("GrandaMento", address(0x1));
            registry.setAddressFor("Exchange", address(exchange));
            //registry.setAddressFor("SortedOracles", address(sortedOracles));
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(registry)));

        // Log the deployed contract addresses.
        console2.log("Deployment of Mento Registry at address", address(registry));
        console2.log("Deployment of Mento Reserve at address", address(reserve));
        console2.log("Deployment of Mento Exchange at address", address(exchange));
        console2.log("Deployment of Mento Token at address", address(token));
        console2.log("Deployment of Mento Freezer at address", address(freezer));
    }
}
