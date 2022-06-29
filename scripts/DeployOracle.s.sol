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
        uint reportExpirationTime
            = vm.envUint("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME");
        uint reportDelay
            = vm.envUint("DEPLOYMENT_ORACLE_REPORT_DELAY");
        uint minimumProviders
            = vm.envUint("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS");

        // Check settings.
        require(
            reportExpirationTime != 0,
            "DeployOracle: Missing env variable: report expiration time"
        );
        require(
            reportDelay != 0,
            "DeployOracle: Missing env variable: report delay"
        );
        require(
            minimumProviders != 0,
            "DeployOracle: Missing env variable: minimum providers"
        );

        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("TRUSTED_OWNER");
        require(
            newOwner != address(0),
            "DeployOracle: Missing env variable: trusted owner"
        );

        // Deploy the oracle.
        vm.startBroadcast();
        {
            oracle = new Oracle(
                reportExpirationTime,
                reportDelay,
                minimumProviders
            );
        }
        vm.stopBroadcast();

        // Log the deployed oracle contract address.
        console2.log("Deployment of Oracle at address", address(oracle));

        // Initiate owner switch.
        vm.startBroadcast();
        {
            oracle.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(
            oracle.pendingOwner() == newOwner,
            "DeployOracle: Initiating owner switch failed"
        );

        // Log successful initiation of the owner switch.
        console2.log(
            "Owner switch succesfully initiated to address",
            newOwner
        );
    }

}
