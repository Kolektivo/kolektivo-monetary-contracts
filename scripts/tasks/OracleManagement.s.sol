pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Oracle} from "../../src/Oracle.sol";

contract AddProvider is Script {
    function run() external {
        // Get env variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));

        // Set new DataProvider to Oracle
        vm.startBroadcast(deployerPrivateKey);
        {
            oracle.addProvider(vm.envAddress("TASK_DATA_PROVIDER"));
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
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        Oracle oracle = Oracle(vm.envAddress("TASK_ORACLE"));
        uint256 price;
        bool valid;

        // Set new DataProvider to Oracle
        vm.startBroadcast(deployerPrivateKey);
        {
            (price, valid) = oracle.getData();
        }
        vm.stopBroadcast();

        console2.log("Pushed price in Oracle ", vm.envString("TASK_ORACLE"), "is ", price);
    }
}
