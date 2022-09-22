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
        ReserveToken(0x799aC807A4163899c09086A6C69490f6AecD65Cb);

    Oracle treasuryOracle = Oracle(0x07aDaa5739fF6d730CB9D59991072b17a70D9813);
    Oracle reserveOracle = Oracle(0x8684e1f9da7036adFF3D95BA54Db9Ef0F503f5D4);
    Oracle erc20Mock1Oracle =
        Oracle(0x8e44992e836A742Cdcde08346DB6ECEac86C5C41);
    Oracle erc20Mock2Oracle =
        Oracle(0x1A9617212f01846961256717781214F9956512Be);
    Oracle erc20Mock3Oracle =
        Oracle(0xBbD9C2bB9901464ef92dbEf3E2DE98b744bA49D5);
    Oracle geoNFT1Oracle = Oracle(0x4CF7C83253B850BC50dC641aB7D4136aE934f77f);
    Oracle geoNFT2Oracle = Oracle(0x5dfD0c7d607a08F07F3041a86338404442615127);

    address reserve = 0x9f4995f6a797Dd932A5301f22cA88104e7e42366;

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
            geoNFT1Oracle.addProvider(msg.sender);
            geoNFT2Oracle.addProvider(msg.sender);
        }
        vm.stopBroadcast();
    }
}
