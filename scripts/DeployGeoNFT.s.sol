pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {GeoNFT} from "../src/GeoNFT.sol";

/**
 * @title GeoNFT Deployment Script
 *
 * @dev Script to deploy a new GeoNFT and initiating an owner switch from the
 *      deployer address to another address given via environment variable.
 *
 *      The following environment variables MUST be provided:
 *      - DEPLOYMENT_GEONFT_NAME
 *      - DEPLOYMENT_GEONFT_SYMBOL
 *      - TRUSTED_OWNER
 */
contract DeployGeoNFT is Script {
    GeoNFT nft;

    function run() external {
        // Read deployment settings from environment variables.
        string memory name = vm.envString("DEPLOYMENT_GEONFT_NAME");
        string memory symbol = vm.envString("DEPLOYMENT_GEONFT_SYMBOL");

        // Check settings.
        require(
            bytes(name).length != 0,
            "DeployGeoNFT: Missing env variable: name"
        );
        require(
            bytes(symbol).length != 0,
            "DeployGeoNFT: Missing env variable: symbol"
        );

        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("TRUSTED_OWNER");
        require(
            newOwner != address(0),
            "DeployTreasury: Missing env variable: trusted owner"
        );

        // Deploy the GeoNFT.
        vm.startBroadcast();
        {
            nft = new GeoNFT(name, symbol);
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(nft)));

        // Log the deployed GeoNFT contract address.
        console2.log("Deployment of GeoNFT at address", address(nft));

        // Initiate owner switch.
        vm.startBroadcast();
        {
            nft.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(
            nft.pendingOwner() == newOwner,
            "DeployGeoNFT: Initiating owner switch failed"
        );

        // Log successful initiation of the owner switch.
        console2.log("Owner switch succesfully initiated to address", newOwner);
    }
}
