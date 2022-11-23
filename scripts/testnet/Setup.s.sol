pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {ReserveToken} from "../../src/ReserveToken.sol";
import {Oracle} from "../../src/Oracle.sol";

import {Reserve} from "../../src/Reserve.sol";

/**
 * @dev Setups the testnet contracts. NEEDS TO BE RUN ONLY ONCE.
 *
 *      - Sets the ReserveToken's mintBurner allowance to the Reserve
 *      - Sets the Oracle providers
 */
contract Setup is Script {
    function run() external {
        ReserveToken reserveToken =
            ReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
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

        address reserve = vm.envAddress("DEPLOYMENT_RESERVE");

        // Set ReserveToken's mintBurner allowance to Reserve.
        vm.startBroadcast();
        {
            reserveToken.setMintBurner(reserve);
        }
        vm.stopBroadcast();

        // Set Oracle providers to msg.sender, i.e. the address with which's
        // private key the script is executed.
        vm.startBroadcast();
        {
            treasuryOracle.addProvider(vm.envAddress("WALLET_DEPLOYER"));
            reserveOracle.addProvider(vm.envAddress("WALLET_DEPLOYER"));
            erc20Mock1Oracle.addProvider(vm.envAddress("WALLET_DEPLOYER"));
            erc20Mock2Oracle.addProvider(vm.envAddress("WALLET_DEPLOYER"));
            erc20Mock3Oracle.addProvider(vm.envAddress("WALLET_DEPLOYER"));
            geoNFT1Oracle.addProvider(vm.envAddress("WALLET_DEPLOYER"));
            geoNFT2Oracle.addProvider(vm.envAddress("WALLET_DEPLOYER"));
            
            address ownOracle = vm.envAddress("OWN_ORACLE_ADDRESS");
            if(ownOracle != address(0)) {
                treasuryOracle.addProvider(ownOracle);
                reserveOracle.addProvider(ownOracle);
                erc20Mock1Oracle.addProvider(ownOracle);
                erc20Mock2Oracle.addProvider(ownOracle);
                erc20Mock3Oracle.addProvider(ownOracle);
                geoNFT1Oracle.addProvider(ownOracle);
                geoNFT2Oracle.addProvider(ownOracle);
            }
        }
        vm.stopBroadcast();
    }
}
