pragma solidity 0.8.10;

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
    // Note that the addresses are copied from the DEPLOYMENT.md doc file.
    ReserveToken reserveToken =
        ReserveToken(0x6f10D2FbcBEa5908bc0d4ed3656E61c29Db9c324);

    Oracle treasuryOracle = Oracle(0xED282D1EAbd32C3740Ee82fa1A95bd885A69f3bB);
    Oracle reserveOracle = Oracle(0xA6B5122385c8aF4a42E9e9217301217B9cdDbC49);
    Oracle erc20Mock1Oracle =
        Oracle(0x2066a9c878c26FA29D4fd923031C3C40375d1c0D);
    Oracle erc20Mock2Oracle =
        Oracle(0xce37a77D34f05325Ff1CC0744edb2845349307F7);
    Oracle erc20Mock3Oracle =
        Oracle(0x923b14F630beA5ED3D47338469c111D6d082B3E8);
    Oracle geoNFTOracle = Oracle(0xFeF224e7fdFf2279AE42c33Fb47397A89503186b);

    address reserve = 0xBccd7dA2A8065C588caFD210c33FC08b00d36Df9;

    function run() external {
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
            treasuryOracle.addProvider(msg.sender);
            reserveOracle.addProvider(msg.sender);
            erc20Mock1Oracle.addProvider(msg.sender);
            erc20Mock2Oracle.addProvider(msg.sender);
            erc20Mock3Oracle.addProvider(msg.sender);
            geoNFTOracle.addProvider(msg.sender);
        }
        vm.stopBroadcast();
    }
}
