pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {ERC20Mock} from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @title ERC20Mock Deployment Script
 *
 * @dev Script to deploy a new ERC20Mock token.
 */
contract DeployERC20Mock is Script {
    ERC20Mock token1;
    ERC20Mock token2;

    function run() external {
        string memory name1 = "Test cUSD";
        string memory symbol1 = "T-cUSD";
        string memory name2 = "Test kCUR";
        string memory symbol2 = "T-kCUR";

        uint8 decimals = uint8(18);

        vm.startBroadcast();
        {
            token1 = new ERC20Mock(name1, symbol1, decimals);
            token1.mint(0xdE8DcD65042db880006421dD3ECA5D94117642d1, 10000e18);
            token2 = new ERC20Mock(name2, symbol2, decimals);
            token2.mint(0xdE8DcD65042db880006421dD3ECA5D94117642d1, 10000e18);
        }
        vm.stopBroadcast();

        // Log the deployed Token contract address.
        console2.log("Deployment of T-cUSD at address", address(token1));
        console2.log("Deployment of T-kCUR at address", address(token2));
    }
}
