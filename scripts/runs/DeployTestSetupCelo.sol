pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../DeployOracle.s.sol";
import "../DeployGeoNFT.s.sol";
import "../DeployReserveToken.s.sol";
import "../DeployReserve.s.sol";
import "../DeployTreasury.s.sol";
import "../mocks/DeployERC20Mock.s.sol";

import "../testnet/Setup.s.sol";
import "../testnet/IncurDebt.s.sol";
import "../testnet/BondAssetsIntoReserve.s.sol";
import "../testnet/BondAssetsIntoTreasury.s.sol";
contract DeployTestSetupCelo is Script {

    function run() external {
        DeployOracle deployOracle = new DeployOracle();
        DeployERC20Mock deployERC20Mock = new DeployERC20Mock();
        DeployGeoNFT deployGeoNFT = new DeployGeoNFT();
        DeployReserveToken deployReserveToken = new DeployReserveToken();
        DeployReserve deployReserve = new DeployReserve();
        DeployTreasury deployTreasury = new DeployTreasury(); 

        Setup setup = new Setup();
        IncurDebt incurDebt = new IncurDebt();
        BondAssetsIntoReserve bondAssetsIntoReserve = new BondAssetsIntoReserve();
        BondAssetsIntoTreasury bondAssetsIntoTreasury = new BondAssetsIntoTreasury();
        

        console2.log("Running deployment script, deploying a testnet scenario to Celo.");


        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME", "1660744843");
        vm.setEnv("DEPLOYMENT_ORACLE_REPORT_DELAY", "0");
        vm.setEnv("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS", "1");
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_TREASURY_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_MOCK_TOKEN_1_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_MOCK_TOKEN_2_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_MOCK_TOKEN_3_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_GEO_NFT_1_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_GEO_NFT_2_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));


        vm.setEnv("DEPLOYMENT_TOKEN_NAME", "Test Token #1");
        vm.setEnv("DEPLOYMENT_TOKEN_SYMBOL", "TT1");
        deployERC20Mock.run();
        vm.setEnv("DEPLOYMENT_MOCK_TOKEN_1", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        vm.setEnv("DEPLOYMENT_TOKEN_NAME", "Test Token #2");
        vm.setEnv("DEPLOYMENT_TOKEN_SYMBOL", "TT2");
        deployERC20Mock.run();
        vm.setEnv("DEPLOYMENT_MOCK_TOKEN_2", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        vm.setEnv("DEPLOYMENT_TOKEN_NAME", "Test Token #3");
        vm.setEnv("DEPLOYMENT_TOKEN_SYMBOL", "TT3");
        deployERC20Mock.run();
        vm.setEnv("DEPLOYMENT_MOCK_TOKEN_3", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));


        vm.setEnv("DEPLOYMENT_GEONFT_NAME", "GeoNFT Test Contract #1");
        vm.setEnv("DEPLOYMENT_GEONFT_SYMBOL", "GeoT1");
        deployGeoNFT.run();
        vm.setEnv("DEPLOYMENT_GEO_NFT_1", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));


        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_NAME", "Kolektivo Curacao Test Token");
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_SYMBOL", "kCUR-T");
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_MINT_BURNER", vm.toString(msg.sender));
        deployReserveToken.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        vm.setEnv("DEPLOYMENT_RESERVE_MIN_BACKING", "5500");
        vm.setEnv("DEPLOYMENT_RESERVE_VESTING_VAULT", vm.toString(address(1)));
        deployReserve.run();
        vm.setEnv("DEPLOYMENT_RESERVE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        deployTreasury.run();
        vm.setEnv("DEPLOYMENT_TREASURY", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));


        setup.run();

        vm.setEnv("DEPLOYMENT_TOKEN_1_AMOUNT_TREASURY", "617000000000000000000");
        vm.setEnv("DEPLOYMENT_TOKEN_2_AMOUNT_TREASURY", "150000000000000000000000");
        vm.setEnv("DEPLOYMENT_TOKEN_3_AMOUNT_TREASURY", "1450000000000000000000000");
        vm.setEnv("DEPLOYMENT_GEO_NFT_1_PRICE_TREASURY", "14924000000000000000000");
        vm.setEnv("DEPLOYMENT_TOKEN_1_PRICE_TREASURY", "4137640000000000000000");
        vm.setEnv("DEPLOYMENT_TOKEN_2_PRICE_TREASURY", "1000000000000000000");
        vm.setEnv("DEPLOYMENT_TOKEN_3_PRICE_TREASURY", "50000000000000000");
        bondAssetsIntoTreasury.run();

        vm.setEnv("DEPLOYMENT_TOKEN_1_AMOUNT_RESERVE", "119000000000000000000");
        vm.setEnv("DEPLOYMENT_TOKEN_2_AMOUNT_RESERVE", "31000000000000000000000");
        vm.setEnv("DEPLOYMENT_TOKEN_3_AMOUNT_RESERVE", "152500000000000000000000");
        vm.setEnv("DEPLOYMENT_GEO_NFT_2_PRICE_RESERVE", "43887320000000000000000");
        
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_PRICE_", "9870000000000000000");
        vm.setEnv("DEPLOYMENT_TREASURY_TOKEN_PRICE_", "1000000000000000000");
        bondAssetsIntoReserve.run();

        vm.setEnv("DEPLOYMENT_DESIRED_BACKING_AMOUNT_RESERVE", "6750");
        incurDebt.run();

        console2.log(" ");
        console2.log("| Kolektivo Contracts    | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| Treasury               |", vm.envString("DEPLOYMENT_TREASURY") ,"|");
        console2.log("| Reserve                |", vm.envString("DEPLOYMENT_RESERVE") ,"|");
        console2.log("| Reserve Token          |", vm.envString("DEPLOYMENT_RESERVE_TOKEN") ,"|");
        console2.log("| Oracle: Treasury Token |", vm.envString("DEPLOYMENT_TREASURY_TOKEN_ORACLE") ,"|");
        console2.log("| Oracle: Reserve Token  |", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE") ,"|");
        console2.log(" ");
        console2.log("| Other Contracts        | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| ERC20 Mock Token 1     |", vm.envString("DEPLOYMENT_MOCK_TOKEN_1") ,"|");
        console2.log("| ERC20 Mock Token 2     |", vm.envString("DEPLOYMENT_MOCK_TOKEN_2") ,"|");
        console2.log("| ERC20 Mock Token 3     |", vm.envString("DEPLOYMENT_MOCK_TOKEN_3") ,"|");
        console2.log("| Oracle: Mock Token 1   |", vm.envString("DEPLOYMENT_MOCK_TOKEN_1_ORACLE") ,"|");
        console2.log("| Oracle: Mock Token 2   |", vm.envString("DEPLOYMENT_MOCK_TOKEN_2_ORACLE") ,"|");
        console2.log("| Oracle: Mock Token 3   |", vm.envString("DEPLOYMENT_MOCK_TOKEN_3_ORACLE") ,"|");
        console2.log("| GeoNFT 1               |", vm.envString("DEPLOYMENT_GEO_NFT_1") ,"|");
        console2.log("| Oracle: GeoNFT 1 ID 1  |", vm.envString("DEPLOYMENT_GEO_NFT_1_ORACLE") ,"|");
        console2.log("| Oracle: GeoNFT 1 ID 2  |", vm.envString("DEPLOYMENT_GEO_NFT_2_ORACLE") ,"|");
        console2.log(" ");
        
        console2.log("To initiate the ownership switch at a later time, ");
        console2.log("copy these and put into console: ");
        string memory exportValues = string(abi.encodePacked("export DEPLOYMENT_TREASURY=", vm.envString("DEPLOYMENT_TREASURY"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_RESERVE=", vm.envString("DEPLOYMENT_RESERVE"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_RESERVE_TOKEN=", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_TREASURY_TOKEN_ORACLE=", vm.envString("DEPLOYMENT_TREASURY_TOKEN_ORACLE"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_RESERVE_TOKEN_ORACLE=", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_MOCK_TOKEN_1_ORACLE=", vm.envString("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_MOCK_TOKEN_2_ORACLE=", vm.envString("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_MOCK_TOKEN_3_ORACLE=", vm.envString("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_GEO_NFT_1_ORACLE=", vm.envString("DEPLOYMENT_GEO_NFT_1_ORACLE"), " && "));
        exportValues = string(abi.encodePacked(exportValues, "export DEPLOYMENT_GEO_NFT_2_ORACLE=", vm.envString("DEPLOYMENT_GEO_NFT_2_ORACLE")));
        console2.log(exportValues);
        
    }
}
