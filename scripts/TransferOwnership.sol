pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {Treasury} from "../src/Treasury.sol";
import {Reserve} from "../src/Reserve.sol";
import {ReserveToken} from "../src/ReserveToken.sol";
import {Oracle} from "../src/Oracle.sol";

/**
 * @title Treasury Deployment Script
 *
 * @dev Script to deploy a new treasury and initiating an owner switch from the
 *      deployer address to another address given via environment variable.
 *
 *      The following environment variables MUST be provided:
 *      - TRUSTED_OWNER
 */
contract TransferOwnership is Script {

    function run() external {
        Treasury treasury = Treasury(vm.envAddress("DEPLOYMENT_TREASURY"));
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        ReserveToken reserveToken = ReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        Oracle treasuryOracle = Oracle(vm.envAddress("DEPLOYMENT_TREASURY_TOKEN_ORACLE"));
        Oracle reserveOracle = Oracle(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN_ORACLE"));
        Oracle erc20Mock1Oracle =
            Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"));
        Oracle erc20Mock2Oracle =
            Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"));
        Oracle erc20Mock3Oracle =
            Oracle(vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"));
        Oracle geoNFT1Oracle = Oracle(vm.envAddress("DEPLOYMENT_GEO_NFT_1_ORACLE"));
        Oracle geoNFT2Oracle = Oracle(vm.envAddress("DEPLOYMENT_GEO_NFT_2_ORACLE"));

        // Read owner settings from environment variables.
        address newOwner = vm.envAddress("NEW_OWNER");
        require(
            newOwner != address(0),
            "DeployTreasury: Missing env variable: trusted owner"
        );


        // Initiate owner switch.
        vm.startBroadcast();
        {
            treasury.setPendingOwner(newOwner);
            reserve.setPendingOwner(newOwner);
            reserveToken.setPendingOwner(newOwner);
            treasuryOracle.setPendingOwner(newOwner);
            reserveOracle.setPendingOwner(newOwner);
            erc20Mock1Oracle.setPendingOwner(newOwner);
            erc20Mock2Oracle.setPendingOwner(newOwner);
            erc20Mock3Oracle.setPendingOwner(newOwner);
            geoNFT1Oracle.setPendingOwner(newOwner);
            geoNFT2Oracle.setPendingOwner(newOwner);
        }
        vm.stopBroadcast();

        // Check initiation of owner switch.
        require(
            reserveOracle.pendingOwner() == newOwner,
            "DeployTreasury: Initiating owner switch failed"
        );

        // Log successful initiation of the owner switch.
        console2.log("Owner switch succesfully initiated to address", newOwner);

        // Print addresses for the multi-sig ownership transfer
        console2.log("List of addresses for the multi-sig to accept ownership in: ");
        console2.log("- ", vm.envAddress("DEPLOYMENT_TREASURY"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_RESERVE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_TREASURY_TOKEN_ORACLE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_RESERVE_TOKEN_ORACLE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_GEO_NFT_1_ORACLE"));
        console2.log("- ", vm.envAddress("DEPLOYMENT_GEO_NFT_2_ORACLE"));
    }
}
