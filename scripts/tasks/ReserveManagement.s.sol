pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {CuracaoReserveToken} from "../../src/CuracaoReserveToken.sol";
import {Reserve} from "../../src/Reserve.sol";
import {IReserve} from "../../src/interfaces/IReserve.sol";

// Sets a MintBurner address for the Reserve token.
contract SetMintBurner is Script {
    function run() external {
        // Get env variables
        CuracaoReserveToken reserveToken = CuracaoReserveToken(vm.envAddress("TASK_RESERVE_TOKEN"));
        address mintBurner = vm.envAddress("TASK_MINT_BURNER");

        // Set new mintBurner
        vm.startBroadcast();
        {
            reserveToken.setMintBurner(mintBurner, true);
        }
        vm.stopBroadcast();

        console2.log(
            "MintBurner with address ",
            vm.envString("TASK_MINT_BURNER"),
            "set within CuracaoReserveToken ",
            vm.envString("TASK_RESERVE_TOKEN")
        );
    }
}

contract RegisterERC20 is Script {
    function run() external {
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        address erc20 = vm.envAddress("TASK_REGISTERERC20_TOKEN");
        address oracle = vm.envAddress("TASK_ORACLE");
        uint256 assetType = vm.envUint("TASK_TOKEN_ASSET_TYPE");
        uint256 riskLevel = vm.envUint("TASK_TOKEN_RISK_LEVEL");

        vm.startBroadcast();
        {
            reserve.registerERC20(erc20, oracle, IReserve.AssetType(assetType), IReserve.RiskLevel(riskLevel));
        }
        vm.stopBroadcast();
    }
}

contract DeregisterERC20 is Script {
    function run() external {
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        address erc20 = vm.envAddress("TASK_REGISTERERC20_TOKEN");

        vm.startBroadcast();
        {
            reserve.deregisterERC20(erc20);
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

contract GetTokenOracle is Script {
    function run() external {
        // Get env variables
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        address tokenOracle;

        // Set new DataProvider to Oracle
        vm.startBroadcast();
        {
            tokenOracle = reserve.tokenOracle();
        }
        vm.stopBroadcast();

        console2.log(
            "kCUR Oracle with address  ",
            tokenOracle,
            " set for Reserve with address ",
            vm.envString("DEPLOYMENT_RESERVE")
        );
    }
}

contract SetMinBacking is Script {
    function run() external {
        // Get env variables
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        uint256 minBacking = vm.envUint("DEPLOYMENT_RESERVE_MIN_BACKING");

        // Set new DataProvider to Oracle
        vm.startBroadcast();
        {
            reserve.setMinBacking(minBacking);
        }
        vm.stopBroadcast();

        console2.log("For Reserve with address: ", address(reserve), ", minimum backing set to: ", minBacking);
    }
}

contract GetMinBacking is Script {
    function run() external {
        // Get env variables
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        uint256 minBacking;

        // Set new DataProvider to Oracle
        vm.startBroadcast();
        {
            minBacking = reserve.minBacking();
        }
        vm.stopBroadcast();

        console2.log("For Reserve with address: ", address(reserve), ", minimum backing is at: ", minBacking);
    }
}

contract IncurDebt is Script {
    function run() external {
        // Get env variables
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        uint256 amount = vm.envUint("TASK_RESERVE_INCUR_DEBT");

        // Set new DataProvider to Oracle
        vm.startBroadcast();
        {
            reserve.incurDebt(amount);
        }
        vm.stopBroadcast();

        console2.log("For Reserve with address: ", address(reserve), ", mint amount kCUR: ", amount);
    }
}

contract GetReserveStatus is Script {
    function run() external {
        // Get env variables
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        uint256 reserveValuation;
        uint256 reserveSupply;
        uint256 minBacking;

        // Get Reserve status
        vm.startBroadcast();
        {
            (reserveValuation, reserveSupply, minBacking) = reserve.reserveStatus();
        }
        vm.stopBroadcast();

        console2.log(
            "Reserve Status of Reserve with address ", address(reserve), "reserve valuation: ", reserveValuation
        );
        console2.log(", reserve supply: ", reserveSupply, ", backing: ", minBacking);
    }
}

contract GetOraclePerERC20 is Script {
    function run() external {
        // Get env variables
        Reserve reserve = Reserve(vm.envAddress("DEPLOYMENT_RESERVE"));
        address erc20 = vm.envAddress("TASK_REGISTERERC20_TOKEN");
        address oracle;

        // Get Reserve status
        vm.startBroadcast();
        {
            oracle = reserve.oraclePerERC20(erc20);
        }
        vm.stopBroadcast();

        console2.log("For Reserve with address ", address(reserve), " , for the ERC20 token ", erc20);
        console2.log(" , the Oracle address is ", oracle);
    }
}
