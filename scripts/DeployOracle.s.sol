pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Oracle} from "../src/Oracle.sol";

/**
 * @title Oracle Deployment Script
 *
 * @dev Script to deploy a new oracle and initiating an owner switch from the
 *      deployer address to another address given via environment variable.
 *
 *      The following environment variables MUST be provided:
 *      - DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME
 *      - DEPLOYMENT_ORACLE_REPORT_DELAY
 *      - DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS
 *      - TRUSTED_OWNER
 */
contract DeployOracle is Script {
    Oracle oracle;

    function run() external {
        // Read deployment settings from environment variables.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 reportExpirationTime = vm.envUint("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME");
        uint256 reportDelay = vm.envUint("DEPLOYMENT_ORACLE_REPORT_DELAY");
        uint256 minimumProviders = vm.envUint("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS");

        // Check settings.
        require(reportExpirationTime != 0, "DeployOracle: Missing env variable: report expiration time");
        // @todo Is allowed to be 0 for simulation.
        //require(
        //    reportDelay != 0,
        //    "DeployOracle: Missing env variable: report delay"
        //);
        require(minimumProviders != 0, "DeployOracle: Missing env variable: minimum providers");

        // Deploy the oracle.
        vm.startBroadcast(deployerPrivateKey);
        {
            oracle = new Oracle(
                reportExpirationTime,
                reportDelay,
                minimumProviders
            );
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(oracle)));

        // Log the deployed oracle contract address.
        console2.log("Deployment of Oracle at address", address(oracle));
    }
}
