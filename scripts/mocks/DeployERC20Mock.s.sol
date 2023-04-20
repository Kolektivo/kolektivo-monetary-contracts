pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {ERC20Mock} from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @title ERC20Mock Deployment Script
 *
 * @dev Script to deploy a new ERC20Mock token.
 */
contract DeployERC20Mock is Script {
    ERC20Mock token;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory name = "MockToken";
        if (bytes(vm.envString("DEPLOYMENT_TOKEN_NAME")).length != 0) {
            name = vm.envString("DEPLOYMENT_TOKEN_NAME");
        }

        string memory symbol = "MT";
        if (bytes(vm.envString("DEPLOYMENT_TOKEN_SYMBOL")).length != 0) {
            symbol = vm.envString("DEPLOYMENT_TOKEN_SYMBOL");
        }

        uint8 decimals = uint8(18);

        vm.startBroadcast(deployerPrivateKey);
        {
            token = new ERC20Mock(name, symbol, decimals);
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(token)));

        // Log the deployed Token contract address.
        console2.log("Deployment of ERC20Mock at address", address(token));
    }
}
