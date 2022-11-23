pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {Reserve} from "../src/Reserve.sol";

/**
 * @title Reserve Deployment Script
 *
 * @dev Script to deploy a new Reserve and initiating an owner switch from
 *      the deployer address to another address given via environment
 *      variable.
 *
 *      The following environment variables MUST be provided:
 *      - TRUSTED_OWNER
 */
contract DeployReserve is Script {
    Reserve reserve;

    function run() external {
        // Read deployment settings from environment variables.
        address token = vm.envAddress("DEPLOYMENT_RESERVE_TOKEN");
        address tokenOracle = vm.envAddress("DEPLOYMENT_RESERVE_TOKEN_ORACLE");
        address vestingVault = vm.envAddress(
            "DEPLOYMENT_RESERVE_VESTING_VAULT"
        );
        uint minBacking = vm.envUint("DEPLOYMENT_RESERVE_MIN_BACKING");

        // Check settings.
        require(
            token != address(0),
            "DeployReserve: Missing env variable: token"
        );
        require(
            tokenOracle != address(0),
            "DeployReserve: Missing env variable: token oracle"
        );
        require(
            vestingVault != address(0),
            "DeployReserve: Missing env variable: vesting vault"
        );
        require(
            minBacking != 0,
            "DeployReserve: Missing env variable: min backing"
        );

        // Deploy the Reserve.
        vm.startBroadcast();
        {
            reserve = new Reserve(token, tokenOracle, vestingVault, minBacking);
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(reserve)));

        // Log the deployed Reserve contract address.
        console2.log("Deployment of Reserve at address", address(reserve));
    }
}
