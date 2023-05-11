pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {BalancerV2Proxy} from "../src/dex/BalancerV2Proxy.sol";
import {CuracaoReserveToken} from "../src/CuracaoReserveToken.sol";

/**
 * @title Proxy Pool Deployment Script
 *
 * @dev Script to deploy a new GeoNFT and initiating an owner switch from the
 *      deployer address to another address given via environment variable.
 *
 *      The following environment variables MUST be provided:
 *      - DEPLOYMENT_GEONFT_NAME
 *      - DEPLOYMENT_GEONFT_SYMBOL
 *      - TRUSTED_OWNER
 */
contract DeployProxyPool is Script {
    BalancerV2Proxy proxyPool;
    CuracaoReserveToken curacaoReserveToken;

    function run() external {
        // Read deployment settings from environment variables.
        address pairToken = vm.envAddress("DEPLOYMENT_PROXY_PAIR_TOKEN");
        address vault = vm.envAddress("DEPLOYMENT_PROXY_VAULT");
        address reserve = vm.envAddress("DEPLOYMENT_RESERVE");
        uint256 ceilingMultiplier = vm.envUint("DEPLOYMENT_PROXY_MULTIPLIER");
        uint256 ceilingTradeShare = vm.envUint("DEPLOYMENT_PROXY_CEILING_SHARES");
        uint256 floorTradeShare = vm.envUint("DEPLOYMENT_PROXY_FLOOR_SHARES");

        curacaoReserveToken = CuracaoReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        // Check settings.
        // require(bytes(name).length != 0, "DeployGeoNFT: Missing env variable: name");
        // require(bytes(symbol).length != 0, "DeployGeoNFT: Missing env variable: symbol");

        // Deploy the GeoNFT.
        vm.startBroadcast();
        {
            proxyPool =
                new BalancerV2Proxy(pairToken, vault, reserve, ceilingMultiplier, ceilingTradeShare, floorTradeShare);
            curacaoReserveToken.setMintBurner(address(proxyPool), true);
        }
        vm.stopBroadcast();

        // Store deployment address in env
        vm.setEnv("LAST_DEPLOYED_CONTRACT_ADDRESS", vm.toString(address(proxyPool)));

        // Log the deployed GeoNFT contract address.
        console2.log("Deployment of Proxy Pool at address", address(proxyPool));
    }
}
