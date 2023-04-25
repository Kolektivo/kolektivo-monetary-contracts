pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Exchange} from "../../src/mento/MentoExchange.sol";
import {MentoReserve} from "../../src/mento/MentoReserve.sol";
import {Registry} from "../../src/mento/MentoRegistry.sol";
import {Freezer} from "../../src/mento/lib/Freezer.sol";
import {FixidityLib} from "../../src/mento/lib/FixidityLib.sol";
import {SortedOracles} from "../../src/mento/SortedOracles.sol";

contract AddOracle is Script {
    function run() external {
        // Address allowed to provide price data
        address oracle = vm.envAddress("TASK_SORTED_ORACLE_PROVIDER");
        address token = vm.envAddress("TASK_SORTED_ORACLE_TOKEN");

        SortedOracles sortedOracles = SortedOracles(vm.envAddress("DEPLOYMENT_MENTO_SORTED_ORACLES"));

        vm.startBroadcast();
        {
            sortedOracles.addOracle(token, oracle);
        }
        vm.stopBroadcast();

        console2.log("DataProvider: ", oracle, " set for token: ", token);
        console2.log("for SortedOracle with address: ", address(sortedOracles));
    }
}
