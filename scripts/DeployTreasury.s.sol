pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Treasury} from "../src/Treasury.sol";

/**
 * @title Treasury Deployment Script
 *
 * @dev Script to deploy a new treasury and initiating an owner switch from the
 *      deployer address to another address given via environment variable.
 *
 *      The following environment variables MUST be provided:
 *      - TRUSTED_OWNER
 */
contract DeployTreasury is Script {
    Treasury treasury;

    function run() external {
        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("TRUSTED_OWNER");
        require(
            newOwner != address(0),
            "DeployTreasury: Missing env variable: trusted owner"
        );

        // Deploy the treasury.
        vm.startBroadcast();
        {
            treasury = new Treasury();
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(treasury)));

        // Log the deployed treasury contract address.
        console2.log("Deployment of Treasury at address", address(treasury));

        // Initiate owner switch.
        vm.startBroadcast();
        {
            treasury.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(
            treasury.pendingOwner() == newOwner,
            "DeployTreasury: Initiating owner switch failed"
        );

        // Log successful initiation of the owner switch.
        console2.log("Owner switch succesfully initiated to address", newOwner);
    }
}
