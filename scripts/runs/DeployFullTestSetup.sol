pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../DeployOracle.s.sol";
import "../DeployGeoNFT.s.sol";
import "../DeployReserveToken.s.sol";
import "../DeployReserve.s.sol";
import "../DeployTreasury.s.sol";
import "../DeployMento.s.sol";
import "../mocks/DeployERC20Mock.s.sol";
import "../DeployTimeLockVault.sol";

import "../testnet/Setup.s.sol";
import "../testnet/IncurDebt.s.sol";
import "../testnet/BondAssetsIntoReserve.s.sol";
import "../testnet/BondAssetsIntoTreasury.s.sol";

import {Registry} from "../../src/mento/MentoRegistry.sol";

contract DeployFullTestSetup is Script {
    // ------------------------------------------
    // INPUTS
    // Here are inputs that can be updated depending on the
    // requirements of the deployment
    // ------------------------------------------
    // Kolektivo Oracle Values
    uint256 constant OracleReportExpirationTime = 7200;
    uint256 constant OracleReportDelay = 0;
    uint256 constant OracleMinimumProviders = 1;
    // Kolektivo Reserve
    string constant kCurTokenName = "Kolektivo Curacao Test Token";
    string constant kCurTokenSymbol = "kCUR-T";
    uint256 constant ReserveMinBacking = 5500; // in BPS
    uint256 constant DesiredBackingAmountReserve = 6750; // in BPS
    // Mento
    string constant MentoTokenName = "Kolektivo Curacao Test Guilder";
    string constant MentoTokenSymbol = "kG-T";

    function run() external {
        // Push the Timestamp forward 1.5m blocks if we are on a local test node,
        // otherwise the Oracle expiry values will underflow since the local
        // node starts at timestamp 0
        if (block.chainid == 31337) {
            vm.warp(1500000);
        }

        DeployOracle deployOracle = new DeployOracle();
        DeployERC20Mock deployERC20Mock = new DeployERC20Mock();
        DeployGeoNFT deployGeoNFT = new DeployGeoNFT();
        DeployReserveToken deployReserveToken = new DeployReserveToken();
        DeployReserve deployReserve = new DeployReserve();
        DeployTreasury deployTreasury = new DeployTreasury();
        DeployMento deployMento = new DeployMento();
        DeployTimeLockVault deployTimeLockVault = new DeployTimeLockVault();

        console2.log("Running deployment script, deploying...");

        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME", vm.toString(OracleReportExpirationTime));
        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_DELAY", vm.toString(OracleReportDelay));
        vm.setEnv("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS", vm.toString(OracleMinimumProviders));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_TREASURY_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();

        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_NAME", kCurTokenName);
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_SYMBOL", kCurTokenSymbol);
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_MINT_BURNER", vm.toString(msg.sender));
        deployReserveToken.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        // Deploy VestingVault
        deployTimeLockVault.run();
        vm.setEnv("DEPLOYMENT_TIMELOCKVAULT", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        vm.setEnv("DEPLOYMENT_RESERVE_MIN_BACKING", vm.toString(ReserveMinBacking));
        vm.setEnv("DEPLOYMENT_RESERVE_VESTING_VAULT", vm.envString("DEPLOYMENT_TIMELOCKVAULT"));
        deployReserve.run();
        vm.setEnv("DEPLOYMENT_RESERVE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        address vestingVault = Reserve(vm.envAddress("DEPLOYMENT_RESERVE")).timeLockVault();

        deployTreasury.run();
        vm.setEnv("DEPLOYMENT_TREASURY", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        vm.setEnv("DEPLOYMENT_MENTO_STABLE_TOKEN_NAME", MentoTokenName);
        vm.setEnv("DEPLOYMENT_MENTO_STABLE_TOKEN_SYMBOL", MentoTokenSymbol);
        deployMento.run();
        vm.setEnv("DEPLOYMENT_MENTO_REGISTRY", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        Registry mentoRegistry = Registry(vm.envAddress("DEPLOYMENT_MENTO_REGISTRY"));
        address mentoExchange = mentoRegistry.getAddressForStringOrDie("Exchange");
        address mentoToken = mentoRegistry.getAddressForStringOrDie(vm.envString("DEPLOYMENT_MENTO_TOKEN_SYMBOL"));
        address mentoReserve = mentoRegistry.getAddressForStringOrDie("Reserve");
        address mentoFreezer = mentoRegistry.getAddressForStringOrDie("Freezer");
        address mentoOracle = mentoRegistry.getAddressForStringOrDie("SortedOracles");
        vm.setEnv("DEPLOYMENT_MENTO_TOKEN", vm.toString(mentoToken));

        console2.log(" ");
        console2.log("| Kolektivo Contracts    | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| Treasury               |", vm.envString("DEPLOYMENT_TREASURY"), "|");
        console2.log("| Reserve                |", vm.envString("DEPLOYMENT_RESERVE"), "|");
        console2.log("| Reserve Token          |", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), "|");
        console2.log("| Reserve: Vesting Vault |", vestingVault, "|");
        console2.log("| Oracle: Treasury Token |", vm.envString("DEPLOYMENT_TREASURY_TOKEN_ORACLE"), "|");
        console2.log("| Oracle: Reserve Token  |", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE"), "|");
        console2.log(" ");
        console2.log("| Mento Contracts        | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| Registry               |", address(mentoRegistry), "|");
        console2.log("| Reserve                |", mentoReserve, "|");
        console2.log("| Exchange               |", mentoExchange, "|");
        console2.log("| Freezer                |", mentoFreezer, "|");
        console2.log("| Token                  |", mentoToken, "|");
        console2.log("| SortedOracles          |", mentoOracle, "|");
        console2.log(" ");

        console2.log("To initiate the ownership switch at a later time, ");
        console2.log("copy these and put into console: ");
        string memory exportValues =
            string(abi.encodePacked("export DEPLOYMENT_TREASURY=", vm.envString("DEPLOYMENT_TREASURY"), " && "));
        exportValues = string(
            abi.encodePacked(exportValues, "export DEPLOYMENT_RESERVE=", vm.envString("DEPLOYMENT_RESERVE"), " && ")
        );
        exportValues = string(
            abi.encodePacked(
                exportValues, "export DEPLOYMENT_RESERVE_TOKEN=", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), " && "
            )
        );
        exportValues = string(
            abi.encodePacked(
                exportValues,
                "export DEPLOYMENT_TREASURY_TOKEN_ORACLE=",
                vm.envString("DEPLOYMENT_TREASURY_TOKEN_ORACLE"),
                " && "
            )
        );
        exportValues = string(
            abi.encodePacked(
                exportValues,
                "export DEPLOYMENT_RESERVE_TOKEN_ORACLE=",
                vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE"),
                " && "
            )
        );
        exportValues = string(
            abi.encodePacked(
                exportValues, "export DEPLOYMENT_MENTO_TOKEN=", vm.envString("DEPLOYMENT_MENTO_TOKEN"), " && "
            )
        );
        exportValues = string(
            abi.encodePacked(
                exportValues, "export DEPLOYMENT_MENTO_REGISTRY=", vm.envString("DEPLOYMENT_MENTO_REGISTRY")
            )
        );
        console2.log(exportValues);
    }
}
