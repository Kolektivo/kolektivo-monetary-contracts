pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {DeployGeoNFT} from "../DeployGeoNFT.s.sol";

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
contract TestnetDeployment is Script {
    function run() external {
        DeployGeoNFT geoNFT;
        geoNFT.run();
    }
}
