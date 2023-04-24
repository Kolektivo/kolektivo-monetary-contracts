pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {CuracaoReserveToken} from "../src/CuracaoReserveToken.sol";

/**
 * @title CuracaoReserveToken Deployment Script
 *
 * @dev Script to deploy a new CuracaoReserveToken and initiating an owner switch
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
    CuracaoReserveToken token;

    function run() external {
        // Read deployment settings from environment variables.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory name = vm.envString("DEPLOYMENT_RESERVE_TOKEN_NAME");
        string memory symbol = vm.envString("DEPLOYMENT_RESERVE_TOKEN_SYMBOL");
        address mintBurner = vm.envAddress("DEPLOYMENT_RESERVE_TOKEN_MINT_BURNER");

        // Check settings.
        require(bytes(name).length != 0, "DeployReserveToken: Missing env variable: name");
        require(bytes(symbol).length != 0, "DeployReserveToken: Missing env variable: symbol");
        require(mintBurner != address(0), "DeployReserveToken: Missing env variable: mint burner");

        // Deploy the CuracaoReserveToken.
        vm.startBroadcast(deployerPrivateKey);
        {
            token = new CuracaoReserveToken(name, symbol);
            token.setMintBurner(mintBurner, true);
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(token)));

        // Log the deployed CuracaoReserveToken contract address.
        console2.log("Deployment of CuracaoReserveToken at address", address(token));
    }
}
