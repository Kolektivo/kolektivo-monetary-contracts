pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../DeployOracle.s.sol";
import "../DeployGeoNFT.s.sol";
import "../DeployReserveToken.s.sol";
import "../DeployReserve.s.sol";
import "../DeployTreasury.s.sol";
import "../DeployMento.s.sol";
import "../mocks/DeployERC20Mock.s.sol";
import "../DeployTimeLockVault.sol";

import "../testnet/Setup.s.sol";
import "../testnet/IncurDebt.s.sol";
import "../testnet/BondAssetsIntoReserve.s.sol";
import "../testnet/BondAssetsIntoTreasury.s.sol";

import {MentoReserve} from "../../src/mento/MentoReserve.sol";
import {Registry} from "../../src/mento/MentoRegistry.sol";
import {CuracaoReserveToken} from "../../src/CuracaoReserveToken.sol";
import {KolektivoGuilder} from "../../src/mento/KolektivoGuilder.sol";
import {Exchange} from "../../src/mento/MentoExchange.sol";
import {SortedOracles} from "../../src/mento/SortedOracles.sol";
import {IReserve} from "../../src/interfaces/IReserve.sol";

contract DeployFullTestSetupMento is Script {
    MentoReserve mentoReserve;
    KolektivoGuilder kolektivoGuilder;
    SortedOracles sortedOracles;
    // ------------------------------------------
    // INPUTS
    // Here are inputs that can be updated depending on the
    // requirements of the deployment
    // ------------------------------------------
    // Kolektivo Oracle Values
    // uint256 constant OracleReportExpirationTime = 7200;
    // uint256 constant OracleReportDelay = 0;
    // uint256 constant OracleMinimumProviders = 1;
    // Mock Token Names
    // string constant MockToken1Name = "Test Token #1";
    // string constant MockToken1Symbol = "TT1";
    // string constant MockToken2Name = "Test Token #2";
    // string constant MockToken2Symbol = "TT2";
    // string constant MockToken3Name = "Test Token #3";
    // string constant MockToken3Symbol = "TT3";
    // string constant MockGeoNFTContractName = "Test GeoNFT Contract #1";
    // string constant MockGeoNFTContractSymbol = "GeoT1";
    // Kolektivo Reserve
    string constant kCurTokenName = "Kolektivo Curacao Test Token";
    string constant kCurTokenSymbol = "kCur-T";
    uint256 constant ReserveMinBacking = 5500; // in BPS
    // Mento
    string constant MentoTokenName = "KolektivoGuilder-T";
    string constant MentoTokenSymbol = "kG-T";
    // ------------------------------------------
    // Simulation Values
    // Treasury
    // uint256 constant DeploymentToken1AmountTreasury = 617000000000000000000;
    // uint256 constant DeploymentToken2AmountTreasury = 150000000000000000000000;
    // uint256 constant DeploymentToken3AmountTreasury = 1450000000000000000000000;
    // uint256 constant DeploymentGeoNFT1PriceTreasury = 14924000000000000000000;
    // uint256 constant DeploymentToken1PriceTreasury = 4137640000000000000000;
    // uint256 constant DeploymentToken2PriceTreasury = 1000000000000000000;
    // uint256 constant DeploymentToken3PriceTreasury = 50000000000000000;
    // uint256 constant DeploymentTreasuryTokenPrice = 1000000000000000000; // KTT
    // // Reserve
    // uint256 constant DeploymentToken1AmountReserve = 119000000000000000000;
    // uint256 constant DeploymentToken2AmountReserve = 31000000000000000000000;
    // uint256 constant DeploymentToken3AmountReserve = 152500000000000000000000;
    // uint256 constant DeploymentGeoNFT2PriceReserve = 43887320000000000000000;
    // uint256 constant DeploymentToken5AmountReserve = 119000000000000000000;
    uint256 constant DeploymentReserveTokenPrice = 9870000000000000000; // kCUR
    uint256 constant DeploymentDesiredBackingAmountReserve = 6750; // in BPS

    function run() external {
        // Push the Timestamp forward 1.5m blocks if we are on a local test node,
        // otherwise the Oracle expiry values will underflow since the local
        // node starts at timestamp 0
        if (block.chainid == 31337) {
            vm.warp(1500000);
        }

        DeployOracle deployOracle = new DeployOracle();
        DeployReserveToken deployReserveToken = new DeployReserveToken();
        DeployReserve deployReserve = new DeployReserve();
        DeployMento deployMento = new DeployMento();
        DeployTimeLockVault deployTimeLockVault = new DeployTimeLockVault();

        // addToken = new AddToken();

        // console2.log("Running deployment script, deploying a testnet scenario to Celo.");

        // vm.setEnv("DEPLOYMENT_ORACLE_REPORT_EXPIRATION_TIME", vm.toString(OracleReportExpirationTime));
        // vm.setEnv("DEPLOYMENT_ORACLE_REPORT_DELAY", vm.toString(OracleReportDelay));
        // vm.setEnv("DEPLOYMENT_ORACLE_MINIMUM_PROVIDERS", vm.toString(OracleMinimumProviders));
        // deployOracle.run();
        // vm.setEnv("DEPLOYMENT_TREASURY_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        deployOracle.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // deployOracle.run();
        // vm.setEnv("DEPLOYMENT_MOCK_TOKEN_1_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // deployOracle.run();
        // vm.setEnv("DEPLOYMENT_MOCK_TOKEN_2_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // deployOracle.run();
        // vm.setEnv("DEPLOYMENT_MOCK_TOKEN_3_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // deployOracle.run();
        // vm.setEnv("DEPLOYMENT_GEO_NFT_1_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // deployOracle.run();
        // vm.setEnv("DEPLOYMENT_GEO_NFT_2_ORACLE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        // vm.setEnv("DEPLOYMENT_TOKEN_NAME", MockToken1Name);
        // vm.setEnv("DEPLOYMENT_TOKEN_SYMBOL", MockToken1Symbol);
        // deployERC20Mock.run();
        // vm.setEnv("DEPLOYMENT_MOCK_TOKEN_1", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // vm.setEnv("DEPLOYMENT_TOKEN_NAME", MockToken2Name);
        // vm.setEnv("DEPLOYMENT_TOKEN_SYMBOL", MockToken2Symbol);
        // deployERC20Mock.run();
        // vm.setEnv("DEPLOYMENT_MOCK_TOKEN_2", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // vm.setEnv("DEPLOYMENT_TOKEN_NAME", MockToken3Name);
        // vm.setEnv("DEPLOYMENT_TOKEN_SYMBOL", MockToken3Symbol);
        // deployERC20Mock.run();
        // vm.setEnv("DEPLOYMENT_MOCK_TOKEN_3", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        // vm.setEnv("DEPLOYMENT_GEONFT_NAME", MockGeoNFTContractName);
        // vm.setEnv("DEPLOYMENT_GEONFT_SYMBOL", MockGeoNFTContractSymbol);
        // deployGeoNFT.run();
        // vm.setEnv("DEPLOYMENT_GEO_NFT_1", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_NAME", kCurTokenName);
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_SYMBOL", kCurTokenSymbol);
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_MINT_BURNER", vm.envString("WALLET_DEPLOYER"));
        deployReserveToken.run();
        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        // Deploy VestingVault
        deployTimeLockVault.run();
        vm.setEnv("DEPLOYMENT_RESERVE_VESTING_VAULT", vm.toString(vm.envAddress("LAST_DEPLOYED_CONTRACT_ADDRESS")));

        vm.setEnv("DEPLOYMENT_RESERVE_MIN_BACKING", vm.toString(ReserveMinBacking));
        deployReserve.run();
        vm.setEnv("DEPLOYMENT_RESERVE", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        // address vestingVault = Reserve(vm.envAddress("DEPLOYMENT_RESERVE")).timeLockVault();

        // deployTreasury.run();
        // vm.setEnv("DEPLOYMENT_TREASURY", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));

        // WARNING THIS IS JUST TO TEST THE MINTING
        //  SINCE THIS SCRIPT DOESNT DEPLOY THE KOLEKTIVO RESERVE
        // vm.setEnv("DEPLOYMENT_RESERVE", vm.envString("PUBLIC_KEY"));
        /// END TODO

        vm.setEnv("DEPLOYMENT_MENTO_STABLE_TOKEN_NAME", MentoTokenName);
        vm.setEnv("DEPLOYMENT_MENTO_STABLE_TOKEN_SYMBOL", MentoTokenSymbol);
        deployMento.run();
        vm.setEnv("DEPLOYMENT_MENTO_REGISTRY", vm.envString("LAST_DEPLOYED_CONTRACT_ADDRESS"));
        Registry mentoRegistry = Registry(vm.envAddress("DEPLOYMENT_MENTO_REGISTRY"));
        address mentoExchange = mentoRegistry.getAddressForStringOrDie("Exchange");
        address mentoToken =
            mentoRegistry.getAddressForStringOrDie(vm.envString("DEPLOYMENT_MENTO_STABLE_TOKEN_SYMBOL"));
        address mentoReserve = mentoRegistry.getAddressForStringOrDie("Reserve");
        address mentoFreezer = mentoRegistry.getAddressForStringOrDie("Freezer");
        address mentoOracle = mentoRegistry.getAddressForStringOrDie("SortedOracles");
        vm.setEnv("DEPLOYMENT_MENTO_TOKEN", vm.toString(mentoToken));

        vm.setEnv("DEPLOYMENT_MENTO_EXCHANGE", vm.toString(mentoExchange));
        vm.setEnv("DEPLOYMENT_MENTO_RESERVE", vm.toString(mentoReserve));

        // setup.run();

        // vm.setEnv("DEPLOYMENT_TOKEN_1_AMOUNT_TREASURY", vm.toString(DeploymentToken1AmountTreasury));
        // vm.setEnv("DEPLOYMENT_TOKEN_2_AMOUNT_TREASURY", vm.toString(DeploymentToken2AmountTreasury));
        // vm.setEnv("DEPLOYMENT_TOKEN_3_AMOUNT_TREASURY", vm.toString(DeploymentToken3AmountTreasury));
        // vm.setEnv("DEPLOYMENT_GEO_NFT_1_PRICE_TREASURY", vm.toString(DeploymentGeoNFT1PriceTreasury));
        // vm.setEnv("DEPLOYMENT_TOKEN_1_PRICE_TREASURY", vm.toString(DeploymentToken1PriceTreasury));
        // vm.setEnv("DEPLOYMENT_TOKEN_2_PRICE_TREASURY", vm.toString(DeploymentToken2PriceTreasury));
        // vm.setEnv("DEPLOYMENT_TOKEN_3_PRICE_TREASURY", vm.toString(DeploymentToken3PriceTreasury));
        // bondAssetsIntoTreasury.run();

        // vm.setEnv("DEPLOYMENT_TOKEN_1_AMOUNT_RESERVE", vm.toString(DeploymentToken1AmountReserve));
        // vm.setEnv("DEPLOYMENT_TOKEN_2_AMOUNT_RESERVE", vm.toString(DeploymentToken2AmountReserve));
        // vm.setEnv("DEPLOYMENT_TOKEN_3_AMOUNT_RESERVE", vm.toString(DeploymentToken3AmountReserve));
        // vm.setEnv("DEPLOYMENT_GEO_NFT_2_PRICE_RESERVE", vm.toString(DeploymentGeoNFT2PriceReserve));

        vm.setEnv("DEPLOYMENT_RESERVE_TOKEN_PRICE", vm.toString(DeploymentReserveTokenPrice));
        // vm.setEnv("DEPLOYMENT_TREASURY_TOKEN_PRICE", vm.toString(DeploymentTreasuryTokenPrice));
        // bondAssetsIntoReserve.run();

        // vm.setEnv("DEPLOYMENT_DESIRED_BACKING_AMOUNT_RESERVE", vm.toString(DeploymentDesiredBackingAmountReserve));
        // incurDebt.run();

        MentoReserve mentoReserveInstance = MentoReserve(mentoReserve);
        Exchange mentoExchangeInstance = Exchange(mentoExchange);
        CuracaoReserveToken reserveToken = CuracaoReserveToken(vm.envAddress("DEPLOYMENT_RESERVE_TOKEN"));
        kolektivoGuilder = KolektivoGuilder(mentoToken);
        sortedOracles = SortedOracles(mentoOracle);
        // Fiat value of kCUR * value of kG. Example $0.55 kCUR / $0.55 = 1,0 exchange rate
        uint256 value = 1000000000000000000000000;
        uint256 initialKgSupply = 10e18;
        uint256 buyAmount = 1e18;
        uint256 sellAmount = 15e17;
        address zero = address(0);
        // uint256 maxSellAmount = 100e18;
        // vm.warp(1500000);
        vm.startBroadcast();
        {
            address kGAddress = mentoToken;
            // kG need to be added so the MentoReserve finds knows the ratio
            mentoReserveInstance.addToken(kGAddress);
            mentoReserveInstance.setReserveToken(address(reserveToken));

            // mint kCUR tokens to the MentoReserve as backing
            reserveToken.mint(address(mentoReserveInstance), initialKgSupply);

            // mint kCUR to msg.sender for buy/sell operations
            reserveToken.mint(vm.envAddress("WALLET_DEPLOYER"), initialKgSupply);

            // push kG to kCUR ratio as report. The value is set to 1 i.e., 1kG == 1kCUR in fiat value
            sortedOracles.report(kGAddress, value, zero, zero);
            // activate the mento exchange
            mentoExchangeInstance.activateStable();

            // console2.log("cKUR balance in MentoReserve: ", reserveToken.balanceOf(address(mentoReserveInstance)));
            // Get kG to kCUR ratio. This does not reflect the actual ratio but taked the amount of kCUR,
            // and calculates kG amount from the exchange ratio
            (uint256 kG, uint256 kCUR) = mentoExchangeInstance.getBuyAndSellBuckets(true);
            console2.log("Exchange ratio: kg ", kG, " - kCUR ", kCUR);

            // we dont buy it, we mint it
            // mentoExchangeInstance.buy(vm.envAddress("PUBLIC_KEY"), buyAmount, maxSellAmount, false);
            address callTarget = address(kolektivoGuilder);
            bytes memory callData =
                abi.encodeWithSignature("mint(address,uint256)", vm.envAddress("WALLET_DEPLOYER"), initialKgSupply);
            IReserve(vm.envAddress("DEPLOYMENT_RESERVE")).executeTx(callTarget, callData);
            (kG, kCUR) = mentoExchangeInstance.getBuyAndSellBuckets(true);
            console2.log("Exchange ratio: kg ", kG, " - kCUR ", kCUR);

            // approve tokens to exchange in preparation to the buy call
            reserveToken.approve(address(mentoExchangeInstance), initialKgSupply);

            // Why need * 1e24. Ouput seems the same?
            console.log("First buy-----------------------------------------------");
            mentoExchangeInstance.sell(vm.envAddress("WALLET_DEPLOYER"), sellAmount, buyAmount, true);

            console2.log("kG balance of wallet: ", kolektivoGuilder.balanceOf(vm.envAddress("WALLET_DEPLOYER")));
            console2.log("kCUR balance in Reserve: ", reserveToken.balanceOf(vm.envAddress("DEPLOYMENT_MENTO_RESERVE")));
            vm.warp(block.timestamp + 1 days);
            console2.log("timestamp: ", block.timestamp, "lastUpatedBucket:", mentoExchangeInstance.lastBucketUpdate());

            (kG, kCUR) = mentoExchangeInstance.getBuyAndSellBuckets(true);
            console2.log("Exchange ratio: kg ", kG, " - kCUR ", kCUR);
            console.log("Update Oracle price to ratio of 2 -----------------------------------------------");

            sortedOracles.report(kGAddress, value * 2, address(0), address(0));

            (kG, kCUR) = mentoExchangeInstance.getBuyAndSellBuckets(true);
            console2.log("Exchange ratio: kg ", kG, " - kCUR ", kCUR);
            console.log("Second buy-----------------------------------------------");

            mentoExchangeInstance.sell(vm.envAddress("WALLET_DEPLOYER"), sellAmount, buyAmount, true);
            console2.log("kCUR balance in Reserve: ", reserveToken.balanceOf(vm.envAddress("DEPLOYMENT_MENTO_RESERVE")));
            (kG, kCUR) = mentoExchangeInstance.getBuyAndSellBuckets(true);
            console2.log("Exchange ratio: kg ", kG, " - kCUR ", kCUR);
        }
        vm.stopBroadcast();
        // addToken.run();

        console2.log(" ");
        console2.log("| Kolektivo Contracts    | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        // console2.log("| Treasury               |", vm.envString("DEPLOYMENT_TREASURY"), "|");
        // console2.log("| Reserve                |", vm.envString("DEPLOYMENT_RESERVE"), "|");
        // console2.log("| Reserve Token          |", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), "|");
        // // console2.log("| Reserve: Vesting Vault |", vestingVault, "|");
        // console2.log("| Oracle: Treasury Token |", vm.envString("DEPLOYMENT_TREASURY_TOKEN_ORACLE"), "|");
        // console2.log("| Oracle: Reserve Token  |", vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE"), "|");
        console2.log(" ");
        console2.log("| Mento Contracts        | Address                                    |");
        console2.log("| ---------------------- | ------------------------------------------ |");
        console2.log("| Registry               |", address(mentoRegistry), "|");
        console2.log("| Reserve                |", mentoReserve, "|");
        console2.log("| Exchange               |", mentoExchange, "|");
        console2.log("| Freezer                |", mentoFreezer, "|");
        console2.log("| Token                  |", mentoToken, "|");
        console2.log("| SortedOracles          |", mentoOracle, "|");
        console2.log(" ");
        console2.log("| Other Contracts        | Address                                    |");
        // console2.log("| ---------------------- | ------------------------------------------ |");
        // console2.log("| ERC20 Mock Token 1     |", vm.envString("DEPLOYMENT_MOCK_TOKEN_1"), "|");
        // console2.log("| ERC20 Mock Token 2     |", vm.envString("DEPLOYMENT_MOCK_TOKEN_2"), "|");
        // console2.log("| ERC20 Mock Token 3     |", vm.envString("DEPLOYMENT_MOCK_TOKEN_3"), "|");
        // console2.log("| Oracle: Mock Token 1   |", vm.envString("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"), "|");
        // console2.log("| Oracle: Mock Token 2   |", vm.envString("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"), "|");
        // console2.log("| Oracle: Mock Token 3   |", vm.envString("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"), "|");
        // console2.log("| GeoNFT 1               |", vm.envString("DEPLOYMENT_GEO_NFT_1"), "|");
        // console2.log("| Oracle: GeoNFT 1 ID 1  |", vm.envString("DEPLOYMENT_GEO_NFT_1_ORACLE"), "|");
        // console2.log("| Oracle: GeoNFT 1 ID 2  |", vm.envString("DEPLOYMENT_GEO_NFT_2_ORACLE"), "|");
        console2.log(" ");

        // console2.log("To initiate the ownership switch at a later time, ");
        // console2.log("copy these and put into console: ");
        // string memory exportValues =
        //     string(abi.encodePacked("export DEPLOYMENT_TREASURY=", vm.envString("DEPLOYMENT_TREASURY"), " && "));
        // exportValues = string(
        //     abi.encodePacked(exportValues, "export DEPLOYMENT_RESERVE=", vm.envString("DEPLOYMENT_RESERVE"), " && ")
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_RESERVE_TOKEN=", vm.envString("DEPLOYMENT_RESERVE_TOKEN"), " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues,
        //         "export DEPLOYMENT_TREASURY_TOKEN_ORACLE=",
        //         vm.envString("DEPLOYMENT_TREASURY_TOKEN_ORACLE"),
        //         " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues,
        //         "export DEPLOYMENT_RESERVE_TOKEN_ORACLE=",
        //         vm.envString("DEPLOYMENT_RESERVE_TOKEN_ORACLE"),
        //         " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues,
        //         "export DEPLOYMENT_MOCK_TOKEN_1_ORACLE=",
        //         vm.envString("DEPLOYMENT_MOCK_TOKEN_1_ORACLE"),
        //         " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues,
        //         "export DEPLOYMENT_MOCK_TOKEN_2_ORACLE=",
        //         vm.envString("DEPLOYMENT_MOCK_TOKEN_2_ORACLE"),
        //         " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues,
        //         "export DEPLOYMENT_MOCK_TOKEN_3_ORACLE=",
        //         vm.envString("DEPLOYMENT_MOCK_TOKEN_3_ORACLE"),
        //         " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_GEO_NFT_1_ORACLE=", vm.envString("DEPLOYMENT_GEO_NFT_1_ORACLE"), " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_GEO_NFT_2_ORACLE=", vm.envString("DEPLOYMENT_GEO_NFT_2_ORACLE"), " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_MENTO_TOKEN=", vm.envString("DEPLOYMENT_MENTO_TOKEN"), " && "
        //     )
        // );
        // exportValues = string(
        //     abi.encodePacked(
        //         exportValues, "export DEPLOYMENT_MENTO_REGISTRY=", vm.envString("DEPLOYMENT_MENTO_REGISTRY")
        //     )
        // );
        // console2.log(exportValues);
    }
}
