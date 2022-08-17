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
    ReserveToken reserveToken = ReserveToken(0x65F0B6a36B850a12B06E5492dF4e13659A996796);

    Oracle treasuryOracle  = Oracle(0x526Ab68ce3BEd2913d2B7e37EcaEc0f4ab81Df91);
    Oracle reserveOracle   = Oracle(0xD37aAd04CEbe9675010d05d7D0B33b15f2ED2443);
    Oracle erc20MockOracle = Oracle(0x917443A163adC3BeBFCb5ffD3a9D8161bE503D79);
    Oracle geoNFTOracle    = Oracle(0x38Bac6587302e06Bd84dca779c5Cb25483177667);

    address reserve = 0x61f99350eb8a181693639dF40F0C25371844fc32;

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
            erc20MockOracle.addProvider(msg.sender);
            geoNFTOracle.addProvider(msg.sender);
        }
        vm.stopBroadcast();
    }

}
