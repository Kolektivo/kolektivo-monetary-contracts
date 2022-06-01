pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {GeoNFT} from "../src/GeoNFT.sol";
import {Oracle} from "../src/Oracle.sol";
import {KOL} from "../src/KOL.sol";
import {Reserve} from "../src/Reserve.sol";
import {Treasury} from "../src/Treasury.sol";

contract Deployment is Script {

    Oracle oracle;
    GeoNFT geoNFT;
    Treasury treasury;
    KOL kol;
    Reserve reserve;

    function run() external {
        _deployOracle();
        _deployGeoNFT();
        _deployTreasury();
        _deployKOL();
        _deployReserve();

        // Print deployment addresses.
        console2.log("Deployment of Oracle   at address", address(oracle));
        console2.log("Deployment of GeoNFT   at address", address(geoNFT));
        console2.log("Deployment of Treasury at address", address(treasury));
        console2.log("Deployment of KOL      at address", address(kol));
        console2.log("Deployment of Reserve  at address", address(reserve));
    }

    function _deployOracle() private {
        // Read envirvonment variables.
        uint reportExpirationTime
            = vm.envUint("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME");
        uint reportDelay
            = vm.envUint("DEPLOYMENT_ORACLE_REPORT_DELAY");
        uint minimumProviders
            = vm.envUint("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS");

        // Check environment variables.
        require(
            reportExpirationTime != 0,
            "_deployOracle: Missing env variable: report expiration time"
        );
        require(
            reportDelay != 0,
            "_deployOracle: Missing env variable: report delay"
        );
        require(
            minimumProviders != 0,
            "_deployOracle: Missing env variable: minimum providers"
        );

        // Deploy oracle.
        vm.startBroadcast();
        {
            oracle = new Oracle(
                reportExpirationTime,
                reportDelay,
                minimumProviders
            );
        }
        vm.stopBroadcast();
    }

    function _deployGeoNFT() private {
        // Read envirvonment variables.
        string memory name
            = vm.envString("DEPLOYMENT_GEONFT_NAME");
        string memory symbol
            = vm.envString("DEPLOYMENT_GEONFT_SYMBOL");

        // Check environment variables.
        require(
            bytes(name).length != 0,
            "_deployGeoNFT: Missing env variable: name"
        );
        require(
            bytes(symbol).length != 0,
            "_deployGeoNFT: Missing env variable: symbol"
        );

        // Deploy GeoNFT.
        vm.startBroadcast();
        {
            geoNFT = new GeoNFT(name, symbol);
        }
        vm.stopBroadcast();
    }

    function _deployTreasury() private {
        vm.startBroadcast();
        {
            treasury = new Treasury();
        }
        vm.stopBroadcast();
    }

    function _deployKOL() private {
        vm.startBroadcast();
        {
            kol = new KOL();
        }
        vm.stopBroadcast();
    }

    function _deployReserve() private {
        // Read envirvonment variables.
        uint minBackingInBPS
            = vm.envUint("DEPLOYMENT_RESERVE_MIN_BACKING_IN_BPS");

        // Check environment variables.
        require(
            minBackingInBPS != 0,
            "_deployReserve: Missing env variable: min backing in bps"
        );

        // Check that contract dependencies are deployed already.
        require(
            address(kol) != address(0),
            "_deployReserve: Missing contract deployment: KOL"
        );
        require(
            address(treasury) != address(0),
            "_deployReserve: Missing contract deployment: Treasury"
        );

        // Deploy Reserve.
        vm.startBroadcast();
        {
            reserve = new Reserve(
                address(kol),
                address(treasury),
                minBackingInBPS
            );
        }
        vm.stopBroadcast();
    }

}
