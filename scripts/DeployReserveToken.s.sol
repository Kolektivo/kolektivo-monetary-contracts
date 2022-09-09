pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {ReserveToken} from "../src/ReserveToken.sol";

/**
 * @title ReserveToken Deployment Script
 *
 * @dev Script to deploy a new ReserveToken and initiating an owner switch
 *      from the deployer address to another address given via environment
 *      variable.
 *
 *      The following environment variables MUST be provided:
 *      - DEPLOYMENT_RESERVE_TOKEN_NAME
 *      - DEPLOYMENT_RESERVE_TOKEN_SYMBOL
 *      - DEPLOYMENT_RESERVE_TOKEN_MINT_BURNER
 *      - TRUSTED_OWNER
 */
contract DeployReserveToken is Script {
    ReserveToken token;

    function run() external {
        // Read deployment settings from environment variables.
        string memory name = vm.envString("DEPLOYMENT_RESERVE_TOKEN_NAME");
        string memory symbol = vm.envString("DEPLOYMENT_RESERVE_TOKEN_SYMBOL");
        address mintBurner = vm.envAddress(
            "DEPLOYMENT_RESERVE_TOKEN_MINT_BURNER"
        );

        // Check settings.
        require(
            bytes(name).length != 0,
            "DeployReserveToken: Missing env variable: name"
        );
        require(
            bytes(symbol).length != 0,
            "DeployReserveToken: Missing env variable: symbol"
        );
        require(
            mintBurner != address(0),
            "DeployReserveToken: Missing env variable: mint burner"
        );

        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("TRUSTED_OWNER");
        require(
            newOwner != address(0),
            "DeployReserveToken: Missing env variable: trusted owner"
        );

        // Deploy the ReserveToken.
        vm.startBroadcast();
        {
            token = new ReserveToken(name, symbol, mintBurner);
        }
        vm.stopBroadcast();

        // Log the deployed ReserveToken contract address.
        console2.log("Deployment of ReserveToken at address", address(token));

        // Initiate owner switch.
        vm.startBroadcast();
        {
            token.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(
            token.pendingOwner() == newOwner,
            "DeployReserveToken: Initiating owner switch failed"
        );

        // Log successful initiation of the owner switch.
        console2.log("Owner switch succesfully initiated to address", newOwner);
    }
}
