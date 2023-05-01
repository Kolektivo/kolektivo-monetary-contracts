pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Exchange} from "../../src/mento/Exchange.sol";
import {KolektivoGuilder} from "../../src/mento/KolektivoGuilder.sol";
import {MentoReserve} from "../../src/mento/MentoReserve.sol";
import {Registry} from "../../src/mento/MentoRegistry.sol";
import {Freezer} from "../../src/mento/lib/Freezer.sol";
import {FixidityLib} from "../../src/mento/lib/FixidityLib.sol";
import {SortedOracles} from "../../src/mento/SortedOracles.sol";
import {IReserve} from "../../src/interfaces/IReserve.sol";

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

contract AddToken is Script {
    function run() external {
        // Token address to add to the MentoReserve
        address token = vm.envAddress("TASK_MENTO_RESERVE_ADD_TOKEN");
        MentoReserve mentoReserve = MentoReserve(vm.envAddress("DEPLOYMENT_MENTO_RESERVE"));

        vm.startBroadcast();
        {
            mentoReserve.addToken(token);
        }
        vm.stopBroadcast();

        console2.log("Add token: ", token, " to MentoReserve with address: ", address(mentoReserve));
    }
}

contract TransferExchangeGold is Script {
    function run() external {
        address toAddress = vm.envAddress("TASK_MENTO_KCUR_WITHDRAW_ADDRESS");
        MentoReserve mentoReserve = MentoReserve(vm.envAddress("DEPLOYMENT_MENTO_RESERVE"));
        uint256 value = vm.envUint("TASK_MENTO_KCUR_WITHDRAW_AMOUNT");

        vm.startBroadcast();
        {
            mentoReserve.transferExchangeGold(payable(toAddress), value);
        }
        vm.stopBroadcast();

        console2.log("Amount kCUR: ", value, " withdrawn to address: ", toAddress);
    }
}

contract GetInflationParameters is Script {
    function run() external {
        // Get the inflation parameters from the KolektivoGuilder contract
        KolektivoGuilder kolektivoGuilder = KolektivoGuilder(vm.envAddress("DEPLOYMENT_MENTO_KOLEKTIVO_GUILDER"));
        uint256 rate;
        uint256 factor;
        uint256 updatePeriod;
        uint256 factorLastUpdated;

        vm.startBroadcast();
        {
            (rate, factor, updatePeriod, factorLastUpdated) = kolektivoGuilder.getInflationParameters();
        }
        vm.stopBroadcast();

        console2.log("Inflation rate: ", rate, "- inflation factor: ", factor);
        console2.log("- update period: ", updatePeriod, "- fatorLastUpdated: ", factorLastUpdated);
        console2.log("for KolektivoGuilder with address: ", address(kolektivoGuilder));
    }
}

contract MintInitalKG is Script {
    function run() external {
        // Mint the intial supply of kG, which should be the exact amount of initial kCUR backing
        address kolektivoGuilder = vm.envAddress("DEPLOYMENT_MENTO_KOLEKTIVO_GUILDER");
        uint256 initialKGAmount = vm.envUint("TASK_MENTO_INITIAL_KG");

        vm.startBroadcast();
        {
            bytes memory callData =
                abi.encodeWithSignature("mint(address,uint256)", vm.envAddress("PUBLIC_KEY"), initialKGAmount);
            IReserve(vm.envAddress("DEPLOYMENT_RESERVE")).executeTx(kolektivoGuilder, callData);
        }
        vm.stopBroadcast();

        console2.log(
            "Initial amount of kG minted: ", initialKGAmount, " from kG contract with address: ", kolektivoGuilder
        );
    }
}
