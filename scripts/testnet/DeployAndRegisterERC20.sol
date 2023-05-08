pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve} from "../../src/Reserve.sol";
import {DeployERC20Mock} from "../mocks/DeployERC20Mock.s.sol";
import {ERC20Mock} from "../../test/utils/mocks/ERC20Mock.sol";
import {DeployOracle} from "../DeployOracle.s.sol";
import {AddProvider, PushReport} from "../tasks/OracleManagement.s.sol";
import {RegisterERC20} from "../tasks/ReserveManagement.s.sol";

/**
 * @dev Deploy new ERC20Mock, deploy an Oracle for the token
 *      Add Providers to the Oracle
 *      Push the report to the Oracle
 *      Register token in Reserver
 *      Mint tokens to msg.sender
 */
contract DeployAndRegisterERC20 is Script {
    Reserve reserve;
    DeployOracle deployOracle;
    AddProvider addProvider;
    PushReport pushReport;
    RegisterERC20 registerERC20;
    DeployERC20Mock deployERC20Mock;

    uint256 token1Amount;
    uint256 token2Amount;
    uint256 token3Amount;
    uint256 geoNFT2Price;

    function run() external {
        reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        deployOracle = new DeployOracle();
        addProvider = new AddProvider();
        pushReport = new PushReport();
        registerERC20 = new RegisterERC20();
        deployERC20Mock = new DeployERC20Mock();

        token1Amount = uint256(1e18);

        // Mock token variables
        string memory tokenName = "Celo Dollar Mock";
        string memory tokenSymbol = "cUSD-T";
        uint256 amount = 1000e18;
        // Oracle variables
        uint256 reportExpirationTime = 2592000; // 30 days vm.envUint("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME");
        uint256 reportDelay = 0; // vm.envUint("DEPLOYMENT_ORACLE_REPORT_DELAY");
        uint256 minimumProviders = 1; // vm.envUint("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS");
        address dataProvider1 = 0x7061B54AD655E2C7b01EC40Aded0aBC18Af183f8; // backend service
        address dataProvider2 = 0xC83901A3BcD7A4cd66FA3e2737aA4632312A593F; // dev wallet
        uint256 initialPrice = 1e18;
        // Register ERC20
        uint256 assetType = 1;
        uint256 riskLevel = 0;

        // Deploy token
        vm.setEnv("DEPLOYMENT_TOKEN_NAME", tokenName);
        vm.setEnv("DEPLOYMENT_TOKEN_SYMBOL", tokenSymbol);

        deployERC20Mock.run();
        vm.setEnv("DEPLOYMENT_MOCK_TOKEN", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));
        ERC20Mock mockToken = ERC20Mock(vm.envAddress("DEPLOYMENT_MOCK_TOKEN"));

        // Deploy Oracle
        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME", vm.toString(reportExpirationTime));
        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_DELAY", vm.toString(reportDelay));
        vm.setEnv("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS", vm.toString(minimumProviders));
        deployOracle.run();
        vm.setEnv("TASK_ORACLE", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        // Set Providers 1
        vm.setEnv("TASK_DATA_PROVIDER", vm.toString(dataProvider1));
        addProvider.run();
        // Set Providers 2
        vm.setEnv("TASK_DATA_PROVIDER", vm.toString(dataProvider2));
        addProvider.run();

        // Push report to Oracle
        vm.setEnv("TASK_PUSH_PRICE", vm.toString(initialPrice));
        pushReport.run();

        // Add token to Reserve
        vm.setEnv("TASK_TOKEN_ASSET_TYPE", vm.toString(assetType));
        vm.setEnv("TASK_TOKEN_RISK_LEVEL", vm.toString(riskLevel));
        vm.setEnv("TASK_REGISTERERC20_TOKEN", vm.toString(address(mockToken)));
        registerERC20.run();

        vm.startBroadcast();
        {
            // Mint token
            mockToken.mint(msg.sender, amount);
        }
        vm.stopBroadcast();

        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| ERC20 Mock Token      |", vm.envString("TASK_REGISTERERC20_TOKEN"), "|");
        console2.log("| Mock token Oracle     |", vm.envString("TASK_ORACLE"), "|");
    }
}
