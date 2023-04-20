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
        // Deploy the treasury.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        {
            treasury = new Treasury();
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(treasury)));

        // Log the deployed treasury contract address.
        console2.log("Deployment of Treasury at address", address(treasury));
    }
}
