pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Oracle} from "../../src/Oracle.sol";

contract AddProvider is Script {
    function run() external {
        // Get env variables
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));

        // Set new DataProvider to Oracle
        vm.startBroadcast();
        {
            oracle.addProvider(vm.envAddress("PUBLIC_KEY"));
        }
        vm.stopBroadcast();

        console2.log(
            "DataProvider ",
            vm.envString("TASK_DATA_PROVIDER"),
            " set to Oracle with address  ",
            vm.envString("TASK_ORACLE")
        );
    }
}

contract GetData is Script {
    function run() external {
        // Get env variables
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));
        uint256 price;
        bool valid;

        // Set new DataProvider to Oracle
        vm.startBroadcast();
        {
            (price, valid) = oracle.getData();
        }
        vm.stopBroadcast();

        console2.log("Pushed price in Oracle ", vm.envString("TASK_ORACLE"), "is ", price);
    }
}

contract GetProviders is Script {
    function run() external {
        // Get env variables
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));
        address provider;

        // Get first DataProvider from Oracle
        vm.startBroadcast();
        {
            provider = oracle.providers(0);
        }
        vm.stopBroadcast();

        console2.log("Providers for Oracle ", vm.envString("TASK_ORACLE"), "are ", provider);
    }
}

contract PushReport is Script {
    function run() external {
        // Get env variables
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));

        uint256 report = vm.envUint("TASK_PUSH_PRICE");

        // Push new report to Oracle
        vm.startBroadcast();
        {
            oracle.pushReport(report);
        }
        vm.stopBroadcast();

        console2.log("Price for Oracle ", vm.envString("TASK_ORACLE"), "pushed with value ", report);
    }
}

contract GetMinimumProviders is Script {
    function run() external {
        // Get env variables
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));
        uint256 minProviders;

        // Get minimum number of providers for Oracle
        vm.startBroadcast();
        {
            minProviders = oracle.minimumProviders();
        }
        vm.stopBroadcast();

        console2.log(
            "Minimum number of providers for Oracle ", vm.envString("TASK_ORACLE"), "is set to: ", minProviders
        );
    }
}

contract SetMinimumProviders is Script {
    function run() external {
        // Get env variables
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));
        uint256 minProviders = vm.envUint("TASK_ORACLE_MINIMUM_PROVIDERS");

        // Set minimum number of providers for Oracle
        vm.startBroadcast();
        {
            oracle.setMinimumProviders(minProviders);
        }
        vm.stopBroadcast();

        console2.log(
            "Minimum number of providers for Oracle ", vm.envString("TASK_ORACLE"), "is set to: ", minProviders
        );
    }
}
