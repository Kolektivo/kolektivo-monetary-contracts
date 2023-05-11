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
        require(bytes(name).length != 0, "DeployGeoNFT: Missing env variable: name");
        require(bytes(symbol).length != 0, "DeployGeoNFT: Missing env variable: symbol");

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
    }
}
