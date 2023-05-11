// // SPDX-License-Identifier: GPL-3.0-or-later
// pragma solidity 0.8.10;

// import "forge-std/Test.sol";
// import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
// import "@oz/proxy/transparent/ProxyAdmin.sol";

// import "src/Oracle.sol";
// import "src/Reserve.sol";
// import "src/CuracaoReserveToken.sol";
// import "src/vesting/TimeLockVault.sol";
// import "src/mento/lib/IMentoReserve.sol";

// import "src/mento/Exchange.sol";
// import "src/mento/MentoReserve.sol";
// import "src/mento/MentoRegistry.sol";
// import "src/mento/SortedOracles.sol";
// import "src/mento/lib/Freezer.sol";
// import "src/mento/KolektivoGuilder.sol";
// import {FixidityLib} from "src/mento/lib/FixidityLib.sol";

// import "test/utils/mocks/ERC20Mock.sol";

// /**
//  * Errors library for Oracle's custom errors.
//  * Enables checking for errors with vm.expectRevert(Errors.<Error>).
//  */

// library Errors {}

// /**
//  * @dev Root contract for Oracle Test Contracts.
//  *
//  *      Provides setUp functions, access to common test utils and internal
//  *      variables used throughout testing.
//  */
// abstract contract MentoTest is Test {
//     using FixidityLib for FixidityLib.Fraction;

//     // SuT.
//     ERC20Mock cUSD;
//     Oracle oraclekCUR;
//     Oracle oracleCUSD;
//     CuracaoReserveToken curacaoReserveToken;
//     Reserve kolektivoReserve;
//     TimeLockVault timeLockVault;

//     MentoReserve mentoReserve;
//     Registry mentoRegistry;
//     Exchange mentoExchange;
//     SortedOracles sortedOracles;
//     KolektivoGuilder kolektivoGuilder;
//     Freezer freezer;

//     // Events copied from SuT.

//     // Initial settings.

//     // Oracle
//     uint256 reportExpirationTime = 60 * 10;
//     uint256 reportDelay = 90;
//     uint256 minimumProviders = 1;
//     uint256 priceReportkCUR = 550000000000000000; // 55 cent
//     uint256 priceReportCUSD = 1e18; // $1

//     // cUSD
//     string cUSDName = "Celo Dollar";
//     string cUSDSymbol = "cUSD";
//     IMentoReserve.AssetType assetType = IMentoReserve.AssetType.Stable; // Stable
//     IMentoReserve.RiskLevel riskLevel = IMentoReserve.RiskLevel.Low; // low
//     uint256 mintAmount = 10001e18;

//     // Deploy Reserve Token
//     string kCURName = "Curacao Reserve Token";
//     string kCURSymbol = "kCUR";
//     uint256 incurDebtAmount = 9000e18;

//     // Reserve
//     uint256 constant reserveBacking = 12500; // in BPS
//     // Mento
//     string constant kolektivoGuilderName = "Kolektivo Guilder";
//     string constant kolektivoGuilderSymbol = "kG";
//     uint256 kGInflationRate = FixidityLib.newFixed(1).unwrap(); // set to 100% which disables it
//     uint256 inflationFactorUpdatePeriod = 1 * 365 * 24 * 60 * 60; // 1 year

//     // Provider addresses.
//     address internal p1 = address(1);
//     address internal p2 = address(2);
//     address internal p3 = address(3);

//     //--------------------------------------------------------------------------
//     // Set Up Functions

//     function setUp() public {
//         vm.prank(p1);

//         // Deploy and mint cUSD
//         cUSD = new ERC20Mock(cUSDName, cUSDSymbol, 18);
//         cUSD.mint(p1, mintAmount);

//         // Deploy TimeLockVault
//         timeLockVault = new TimeLockVault();

//         // Setup Oracles
//         oraclekCUR = new Oracle(
//             reportExpirationTime,
//             reportDelay,
//             minimumProviders
//         );
//         oracleCUSD = new Oracle(
//             reportExpirationTime,
//             reportDelay,
//             minimumProviders
//         );
//         // Set block.timestamp to something higher than 1.
//         vm.warp(block.timestamp + 60);
//         // push price
//         oraclekCUR.addProvider(p1);
//         oraclekCUR.pushReport(priceReportkCUR);
//         oracleCUSD.addProvider(p1);
//         oraclekCUR.pushReport(priceReportCUSD);

//         // Deploy reserve token
//         curacaoReserveToken = new CuracaoReserveToken(kCURName, kCURSymbol);
//         // Deploy Reserve
//         kolektivoReserve =
//             new Reserve(address(curacaoReserveToken), address(oraclekCUR), address(timeLockVault), reserveBacking);
//         // set mintburner
//         curacaoReserveToken.setMintBurner(address(kolektivoReserve), true);
//         // Register cUSD in Reserve
//         kolektivoReserve.registerERC20(address(cUSD), address(oracleCUSD), assetType, riskLevel);
//         // Transfer cUSD to Reserve
//         cUSD.transfer(address(kolektivoReserve), 10000e18);
//         // mint kCUR - incurDebt
//         kolektivoReserve.incurDebt(incurDebtAmount);

//         // Deploy Mento Contracts
//         address proxyAdmin = address(new ProxyAdmin());

//         // Freezer
//         address freezerImplementation = address(new Freezer(true));
//         bytes memory initData = abi.encodeWithSignature("initialize()");
//         freezer = Freezer(deployUupsProxy(freezerImplementation, proxyAdmin, initData));

//         // Mento Registry
//         address registryImplementation = address(new Registry(true));
//         initData = abi.encodeWithSignature("initialize()");
//         mentoRegistry = Registry(deployUupsProxy(registryImplementation, proxyAdmin, initData));

//         // Kolektivo Guilder
//         address tokenImplementation = address(new KolektivoGuilder(true));
//         initData = abi.encodeWithSignature(
//             "initialize(string,string,uint8,address,uint256,uint256,string)",
//             kolektivoGuilderName, // _name
//             kolektivoGuilderSymbol, // _symbol
//             18, // _decimals
//             address(mentoRegistry), // registryAddress
//             kGInflationRate, // inflationRate
//             inflationFactorUpdatePeriod, // inflationFactorUpdatePeriod
//             "Exchange" // exchangeIdentifier
//         );
//         kolektivoGuilder = KolektivoGuilder(deployUupsProxy(tokenImplementation, proxyAdmin, initData));

//         bytes32[] memory assetAllocationSymbols = new bytes32[](1);
//         assetAllocationSymbols[0] = bytes32(bytes(kCURSymbol));
//         uint256[] memory assetAllocationWeights = new uint256[](1);
//         assetAllocationWeights[0] = FixidityLib.newFixed(1).unwrap(); // 100%

//         address reserveImplementation = address(new MentoReserve(true));
//         initData = abi.encodeWithSignature(
//             "initialize(address,uint256,uint256,uint256,uint256,bytes32[],uint256[],uint256,uint256)",
//             address(mentoRegistry),
//             24 hours, // _tobinTaxStalenessThreshold
//             FixidityLib.newFixed(1).unwrap(), // _spendingRatio
//             0, // _frozenGold
//             0, // _frozenDays
//             assetAllocationSymbols, // _assetAllocationSymbols
//             assetAllocationWeights, // _assetAllocationWeights
//             0, // _tobinTax
//             FixidityLib.newFixed(1).unwrap() // _tobinTaxReserveRatio,
//         );
//         mentoReserve = MentoReserve(deployUupsProxy(reserveImplementation, proxyAdmin, initData));

//         // address exchangeImplementation = address(new Exchange(true));
//         // initData = abi.encodeWithSignature(
//         //     "initialize(address,string,uint256,uint256,uint256,uint256)",
//         //     address(mentoRegistry), // registryAddress
//         //     kolektivoGuilderSymbol, // stableTokenIdentifier
//         //     FixidityLib.newFixedFraction(25, 10000).unwrap(), // _spread
//         //     FixidityLib.newFixedFraction(9999, 10000).unwrap(), // _reserveFraction
//         //     60 * 60, // _updateFrequency
//         //     1 // _minimumReports
//         // );
//         // mentoExchange = Exchange(deployUupsProxy(exchangeImplementation, proxyAdmin, initData));

//         // sortedOracles = new SortedOracles(false);
//         // sortedOracles.initialize(
//         //     24 * 60 * 60 // report validity
//         // );

//         // // Add Oracles, i.e. data providers to contract
//         // sortedOracles.addOracle(address(kolektivoGuilder), p1);
//         // // sortedOracles.addOracle(reserveToken, oracle);

//         // mentoRegistry.setAddressFor("Freezer", address(freezer));
//         // mentoRegistry.setAddressFor("GoldToken", reserveToken);
//         // mentoRegistry.setAddressFor("Reserve", address(mentoReserve));
//         // mentoRegistry.setAddressFor(tokenSymbol, address(kolektivoGuilder));
//         // mentoRegistry.setAddressFor("GrandaMento", address(0x1));
//         // mentoRegistry.setAddressFor("Exchange", address(mentoExchange));
//         // mentoRegistry.setAddressFor("SortedOracles", address(sortedOracles));
//         // mentoRegistry.setAddressFor("KolektivoCuracaoReserve", address(reserve));

//         // Set block.timestamp to something higher than 1.
//         vm.warp(block.timestamp + 60);
//     }

//     function deployUupsProxy(address contractImplementation, address admin, bytes memory data)
//         public
//         returns (address)
//     {
//         TransparentUpgradeableProxy uups = new TransparentUpgradeableProxy(contractImplementation, admin, data);
//         return address(uups);
//     }
// }
