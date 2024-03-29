pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../DeployOracle.s.sol";
import "../DeployReserveToken.s.sol";
import "../DeployReserve.s.sol";
import "../DeployTimeLockVault.s.sol";

import {AddProvider} from "../tasks/OracleManagement.s.sol";
import {SetMintBurner, RegisterERC20} from "../tasks/ReserveManagement.s.sol";
import {Oracle} from "../../src/Oracle.sol";

contract DeployReserveSystem is Script {
    function run() external {
        // Deployment Contracts
        DeployOracle deployOracle = new DeployOracle();
        DeployReserveToken deployReserveToken = new DeployReserveToken();
        DeployReserve deployReserve = new DeployReserve();
        DeployTimeLockVault deployTimeLockVault = new DeployTimeLockVault();

        // Tasks
        AddProvider addProvider = new AddProvider();
        SetMintBurner setMintBurner = new SetMintBurner();
        RegisterERC20 registerERC20 = new RegisterERC20();

        // Deployment
        console2.log("Running deployment script, deploying the MVP Test scenario to Celo.");

        // Deploy Oracles
        // cUSD
        vm.setEnv("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS", vm.envString("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS"));
        vm.setEnv(
            "DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME", vm.envString("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME_CUSD")
        );
        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_DELAY", vm.envString("DEPLOYMENT_ORACLE_REPORT_DELAY_CUSD"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_cUSD_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // kCUR
        vm.setEnv(
            "DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME", vm.envString("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME_KCUR")
        );
        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_DELAY", vm.envString("DEPLOYMENT_ORACLE_REPORT_DELAY_KCUR"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        // Deploy ReserveToken
        deployReserveToken.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        // Deploy VestingVault
        deployTimeLockVault.run();
        vm.setEnv("DEPLOYMENT_TIMELOCKVAULT", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        // Deploy Reserve
        vm.setEnv("DEPLOYMENT_RESERVE_MIN_BACKING", vm.envString("DEPLOYMENT_RESERVE_MIN_BACKING"));
        vm.setEnv("DEPLOYMENT_RESERVE_VESTING_VAULT", vm.envString("DEPLOYMENT_TIMELOCKVAULT"));
        deployReserve.run();
        vm.setEnv("DEPLOYMENT_RESERVE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        // Add DataProviders
        // kCUR
        vm.setEnv("TASK_DATA_PROVIDER", vm.envString("TASK_DATAPROVIDER_RESERVE_TOKEN_1"));
        vm.setEnv("TASK_ORACLE", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE"));
        addProvider.run();
        // cUSD
        vm.setEnv("TASK_DATA_PROVIDER", vm.envString("TASK_DATAPROVIDER_CUSD_1"));
        vm.setEnv("TASK_ORACLE", vm.envString("DEPLOYMENT_cUSD_TOKEN_ORACLE"));
        addProvider.run();

        // Set Mintburner
        vm.setEnv("TASK_MINT_BURNER", vm.envString("DEPLOYMENT_RESERVE"));
        vm.setEnv("TASK_RESERVE_TOKEN", vm.envString("DEPLOYMENT_RESERVE_TOKEN"));
        setMintBurner.run();

        Oracle cUSDOracle = Oracle(vm.envAddress("DEPLOYMENT_cUSD_TOKEN_ORACLE"));
        Oracle kCUROracle = Oracle(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN_ORACLE"));
        uint256 kCURPrice = 550000000000000000;
        uint256 cUSDPrice = 1e18;
        vm.startBroadcast();
        {
            cUSDOracle.addProvider(vm.envAddress("PUBLIC_KEY"));
            kCUROracle.addProvider(vm.envAddress("PUBLIC_KEY"));
            cUSDOracle.pushReport(cUSDPrice);
            kCUROracle.pushReport(kCURPrice);
        }
        vm.stopBroadcast();

        // Register cUSD in Reserve
        vm.setEnv("TASK_REGISTERERC20_TOKEN", vm.envString("CUSD"));
        // For cUSD - asset type = Stable
        uint256 assetType = 1;
        // For cUSD - risk level = Low
        uint256 riskLevel = 0;
        vm.setEnv("TASK_ORACLE", vm.envString("DEPLOYMENT_cUSD_TOKEN_ORACLE"));
        vm.setEnv("TASK_TOKEN_ASSET_TYPE", vm.toString(assetType));
        vm.setEnv("TASK_TOKEN_RISK_LEVEL", vm.toString(riskLevel));
        registerERC20.run();

        console2.log(" ");
        console2.log("| Kolektivo Contracts    | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| Reserve                |", vm.envString("DEPLOYMENT_RESERVE"), "|");
        console2.log("| Reserve Token          |", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), "|");
        console2.log("| TimeLockVaul           |", vm.envString("DEPLOYMENT_TIMELOCKVAULT"), "|");
        console2.log("| Oracle: cUSD           |", vm.envString("DEPLOYMENT_cUSD_TOKEN_ORACLE"), "|");
        console2.log("| Oracle: Reserve Token  |", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE"), "|");
        console2.log(" ");

        console2.log("To initiate the ownership switch at a later time, ");
        console2.log("copy these and put into console: ");

        string memory exportValues =
            string(abi.encodePacked("export DEPLOYMENT_RESERVE=", vm.envString("DEPLOYMENT_RESERVE"), " && "));
        exportValues = string(
            abi.encodePacked(
                exportValues, "export DEPLOYMENT_RESERVE_TOKEN=", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), " && "
            )
        );
        exportValues = string(
            abi.encodePacked(
                exportValues, "export DEPLOYMENT_TIMELOCKVAULT=", vm.envString("DEPLOYMENT_TIMELOCKVAULT"), " && "
            )
        );
        exportValues = string(
            abi.encodePacked(
                exportValues,
                "export DEPLOYMENT_cUSD_TOKEN_ORACLE=",
                vm.envString("DEPLOYMENT_cUSD_TOKEN_ORACLE"),
                " && "
            )
        );
        exportValues = string(
            abi.encodePacked(
                exportValues, "export DEPLOYMENT_RESERVE_TOKEN_ORACLE=", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE")
            )
        );

        console2.log(exportValues);
    }
}
