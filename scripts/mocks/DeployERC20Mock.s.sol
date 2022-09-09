pragma solidity 0.8.10;

import "forge-std/Script.sol";

import { ERC20Mock } from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @title ERC20Mock Deployment Script
 *
 * @dev Script to deploy a new ERC20Mock token.
 */
contract DeployGeoNFT is Script {
    ERC20Mock token;

    function run() external {
        string memory name = "TestToken #3";
        string memory symbol = "TT3";
        uint8 decimals = uint8(18);

        vm.startBroadcast();
        {
            token = new ERC20Mock(name, symbol, decimals);
        }
        vm.stopBroadcast();

        // Log the deployed Token contract address.
        console2.log("Deployment of ERC20Mock at address", address(token));
    }
}
