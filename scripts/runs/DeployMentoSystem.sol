pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../DeployMento.s.sol";
import {CuracaoReserveToken} from "../../src/CuracaoReserveToken.sol";
import {MentoReserve} from "../../src/mento/MentoReserve.sol";
import {Exchange} from "../../src/mento/MentoExchange.sol";
import {Registry} from "../../src/mento/MentoRegistry.sol";

// import {KolektivoGuilder} from "../../src/mento/KolektivoGuilder.sol";
import {IReserve} from "../../src/interfaces/IReserve.sol";

contract DeployMentoSystem is Script {
    function run() external {
        // Deployment Mento
        DeployMento deployMento = new DeployMento();

        // Deployment
        console2.log("Running deployment script, deploying Mento system om Celo.");

        deployMento.run();
        console2.log("Out of DeployMento0");
        vm.setEnv("DEPLOYMENT_MENTO_REGISTRY", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        Registry mentoRegistry = Registry(vm.envAddress("DEPLOYMENT_MENTO_REGISTRY"));
        console2.log("Out of DeployMento1");
        address mentoExchangeAddress = mentoRegistry.getAddressForStringOrDie("Exchange");
        address kolektivoGuilderAddress =
            mentoRegistry.getAddressForStringOrDie(vm.envString("DEPLOYMENT_MENTO_STABLE_TOKEN_SYMBOL"));
        address mentoReserveAddress = mentoRegistry.getAddressForStringOrDie("Reserve");
        address mentoFreezer = mentoRegistry.getAddressForStringOrDie("Freezer");
        address sortedOraclesAddress = mentoRegistry.getAddressForStringOrDie("SortedOracles");
        vm.setEnv("DEPLOYMENT_MENTO_KOLEKTIVO_GUILDER", vm.toString(kolektivoGuilderAddress));

        vm.setEnv("DEPLOYMENT_MENTO_EXCHANGE", vm.toString(mentoExchangeAddress));
        vm.setEnv("DEPLOYMENT_MENTO_RESERVE", vm.toString(mentoReserveAddress));

        MentoReserve mentoReserve = MentoReserve(mentoReserveAddress);
        Exchange mentoExchange = Exchange(mentoExchangeAddress);
        CuracaoReserveToken curacaoReserveToken = CuracaoReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        // KolektivoGuilder kolektivoGuilder = KolektivoGuilder(kolektivoGuilderAddress);
        console.log(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        console2.log(address(curacaoReserveToken));

        uint256 initialKgSupply = 8000e18;

        console2.log("Out of DeployMento2");
        vm.startBroadcast();
        {
            // kG need to be added, so the MentoReserve finds knows the ratio
            mentoReserve.addToken(kolektivoGuilderAddress);
            console2.log("Out of DeployMento3");
            mentoReserve.setReserveToken(address(curacaoReserveToken));
            console2.log("Out of DeployMento4");

            // console2.log(curacaoReserveToken.totalSupply());
            // console2.log(msg.sender);
            // // transfer kCUR tokens to the MentoReserve as backing
            // curacaoReserveToken.transfer(mentoReserveAddress, initialKgSupply);

            // activate the mento exchange
            mentoExchange.activateStable();

            // we dont buy it, we mint it
            bytes memory callData =
                abi.encodeWithSignature("mint(address,uint256)", vm.envAddress("PUBLIC_KEY"), initialKgSupply);
            IReserve(vm.envAddress("DEPLOYMENT_RESERVE")).executeTx(kolektivoGuilderAddress, callData);
        }
        vm.stopBroadcast();

        console2.log(" ");
        console2.log("| Mento Contracts        | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| Mento Registry         |", address(mentoRegistry), "|");
        console2.log("| Mento Reserve          |", mentoReserveAddress, "|");
        console2.log("| Mento Exchange         |", mentoExchangeAddress, "|");
        console2.log("| Freezer                |", mentoFreezer, "|");
        console2.log("| Kolektivo Guilder      |", kolektivoGuilderAddress, "|");
        console2.log("| SortedOracles          |", sortedOraclesAddress, "|");
        console2.log(" ");

        console2.log("To initiate the ownership switch at a later time, ");
        console2.log("copy these and put into console: ");

        // string memory exportValues =
        //     string(abi.encodePacked("export DEPLOYMENT_RESERVE=", vm.envString("DEPLOYMENT_RESERVE"), " && "));
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_RESERVE_TOKEN=", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_TIMELOCKVAULT=", vm.envString("DEPLOYMENT_TIMELOCKVAULT"), " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues,
        //         "export DEPLOYMENT_cUSD_TOKEN_ORACLE=",
        //         vm.envString("DEPLOYMENT_cUSD_TOKEN_ORACLE"),
        //         " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_RESERVE_TOKEN_ORACLE=", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE")
        //     )
        // );

        // console2.log(exportValues);
    }
}
