pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Reserve2Token} from "../src/Reserve2Token.sol";

/**
 * @title Reserve2Token Deployment Script
 *
 * @dev Script to deploy a new Reserve2Token and initiating an owner switch
 *      from the deployer address to another address given via environment
 *      variable.
 *
 *      The following environment variables MUST be provided:
 *      - DEPLOYMENT_RESERVE2TOKEN_NAME
 *      - DEPLOYMENT_RESERVE2TOKEN_SYMBOL
 *      - DEPLOYMENT_RESERVE2TOKEN_MINT_BURNER
 *      - TRUSTED_OWNER
 */
contract DeployReserve2Token is Script {

    Reserve2Token token;

    function run() external {
        // Read deployment settings from environment variables.
        string memory name
            = vm.envString("DEPLOYMENT_RESERVE2TOKEN_NAME");
        string memory symbol
            = vm.envString("DEPLOYMENT_RESERVE2TOKEN_SYMBOL");
        address mintBurner
            = vm.envAddress("DEPLOYMENT_RESERVE2TOKEN_MINT_BURNER");

        // Check settings.
        require(
            bytes(name).length != 0,
            "DeployReserve2Token: Missing env variable: name"
        );
        require(
            bytes(symbol).length != 0,
            "DeployReserve2Token: Missing env variable: symbol"
        );
        require(
            mintBurner != address(0),
            "DeployReserve2Token: Missing env variable: mint burner"
        );

        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("TRUSTED_OWNER");
        require(
            newOwner != address(0),
            "DeployReserve2Token: Missing env variable: trusted owner"
        );

        // Deploy the Reserve2Token.
        vm.startBroadcast();
        {
            token = new Reserve2Token(name, symbol, mintBurner);
        }
        vm.stopBroadcast();

        // Log the deployed Reserve2Token contract address.
        console2.log("Deployment of Reserve2Token at address", address(token));

        // Initiate owner switch.
        vm.startBroadcast();
        {
            token.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(
            token.pendingOwner() == newOwner,
            "DeployReserve2Token: Initiating owner switch failed"
        );

        // Log successful initiation of the owner switch.
        console2.log(
            "Owner switch succesfully initiated to address",
            newOwner
        );
    }

}
