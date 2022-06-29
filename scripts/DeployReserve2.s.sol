pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve2} from "../src/Reserve2.sol";

/**
 * @title Reserve2 Deployment Script
 *
 * @dev Script to deploy a new Reserve2 and initiating an owner switch from
 *      the deployer address to another address given via environment
 *      variable.
 *
 *      The following environment variables MUST be provided:
 *      - TRUSTED_OWNER
 */
contract DeployReserve2 is Script {

    Reserve2 reserve;

    function run() external {
        // Read deployment settings from environment variables.
        address token
            = vm.envAddress("DEPLOYMENT_RESERVE2_TOKEN");
        address tokenOracle
            = vm.envAddress("DEPLOYMENT_RESERVE2_TOKEN_ORACLE");
        address vestingVault
            = vm.envAddress("DEPLOYMENT_RESERVE2_VESTING_VAULT");
        uint minBacking
            = vm.envUint("DEPLOYMENT_RESERVE2_MIN_BACKING");

        // Check settings.
        require(
            token != address(0),
            "DeployReserve2: Missing env variable: token"
        );
        require(
            tokenOracle != address(0),
            "DeployReserve2: Missing env variable: token oracle"
        );
        require(
            vestingVault != address(0),
            "DeployReserve2: Missing env variable: vesting vault"
        );
        require(
            minBacking != 0,
            "DeployReserve2: Missing env variable: min backing"
        );

        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("TRUSTED_OWNER");
        require(
            newOwner != address(0),
            "DeployReserve2Token: Missing env variable: trusted owner"
        );

        // Deploy the Reserve2.
        vm.startBroadcast();
        {
            reserve = new Reserve2(
                token,
                tokenOracle,
                vestingVault,
                minBacking
            );
        }
        vm.stopBroadcast();

        // Log the deployed Reserve2 contract address.
        console2.log("Deployment of Reserve2 at address", address(reserve));

        // Initiate owner switch.
        vm.startBroadcast();
        {
            reserve.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(
            reserve.pendingOwner() == newOwner,
            "DeployReserve2: Initiating owner switch failed"
        );

        // Log successful initiation of the owner switch.
        console2.log(
            "Owner switch succesfully initiated to address",
            newOwner
        );
    }

}
