pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {ReserveToken} from "../../src/ReserveToken.sol";
import {Reserve} from "../../src/Reserve.sol";
import {IReserve} from "../../src/interfaces/IReserve.sol";

// Sets a MintBurner address for the Reserve token.
contract SetMintBurner is Script {
    function run() external {
        // Get env variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ReserveToken reserveToken = ReserveToken(vm.envAddress("TASK_RESERVE_TOKEN"));
        address mintBurner = vm.envAddress("TASK_MINT_BURNER");

        // Set new mintBurner
        vm.startBroadcast(deployerPrivateKey);
        {
            reserveToken.setMintBurner(mintBurner, true);
        }
        vm.stopBroadcast();

        console2.log(
            "MintBurner with address ",
            vm.envString("TASK_MINT_BURNER"),
            "set within ReserveToken ",
            vm.envString("TASK_RESERVE_TOKEN")
        );
    }
}

contract RegisterERC20 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        address erc20 = vm.envAddress("TASK_REGISTERERC20_TOKEN");
        address oracle = vm.envAddress("TASK_ORACLE");

        IReserve.AssetType tokenAssetType = IReserve.AssetType.Stable;
        IReserve.RiskLevel tokenRiskLevel = IReserve.RiskLevel.Low;

        vm.startBroadcast(deployerPrivateKey);
        {
            reserve.registerERC20(erc20, oracle, tokenAssetType, tokenRiskLevel);
        }
        vm.stopBroadcast();
    }

    // Should be used to get the RiskLevel and AssetType dynamically

    // function getAssetType() internal view returns (IReserve.AssetType) {
    //     if (
    //         keccak256(abi.encodePacked(vm.envString("TASK_REGISTERERC20_ASSET_TYPE")))
    //             == keccak256(abi.encodePacked("Default"))
    //     ) {
    //         return IReserve.AssetType.Default;
    //     } else if (
    //         keccak256(abi.encodePacked(vm.envString("TASK_REGISTERERC20_ASSET_TYPE")))
    //             == keccak256(abi.encodePacked("Stable"))
    //     ) {
    //         return IReserve.AssetType.Stable;
    //     } else {
    //         return IReserve.AssetType.Ecological;
    //     }
    // }

    // function getRiskLevel() internal view returns (IReserve.RiskLevel) {
    //     if (
    //         keccak256(abi.encodePacked(vm.envString("TASK_REGISTERERC20_RISK_LEVEL")))
    //             == keccak256(abi.encodePacked("Low"))
    //     ) {
    //         return IReserve.RiskLevel.Low;
    //     } else if (
    //         keccak256(abi.encodePacked(vm.envString("TASK_REGISTERERC20_RISK_LEVEL")))
    //             == keccak256(abi.encodePacked("Medium"))
    //     ) {
    //         return IReserve.RiskLevel.Medium;
    //     } else {
    //         return IReserve.RiskLevel.High;
    //     }
    // }
}
