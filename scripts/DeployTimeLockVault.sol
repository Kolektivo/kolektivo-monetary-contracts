pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {TimeLockVault} from "../src/vesting/TimeLockVault.sol";

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
contract DeployTimeLockVault is Script {
    TimeLockVault timeLockVault;

    function run() external {
        // Deploy the TimeLockVault.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        {
            timeLockVault = new TimeLockVault();
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(timeLockVault)));

        // Log the deployed TimeLockVault contract address.
        console2.log("Deployment of TimeLockVault at address", address(timeLockVault));
    }
}
