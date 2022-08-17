pragma solidity 0.8.10;

import "forge-std/Script.sol";

import {Treasury} from "../../src/Treasury.sol";
import {Oracle} from "../../src/Oracle.sol";

import {ERC20Mock} from "../../test/utils/mocks/ERC20Mock.sol";

/**
 * @dev Initializes the ERC20Mock token oracle with some price and mints some
 *      ERC20Mock tokens. Aftwards the ERC20Mock is registered inside the
 *      Treasury, approved to be spent by the Treasury and then bonded into
 *      the Treasury.
 *
 *      The ERC20Mock token's price is set to a new value and a Treasury rebase
 *      triggered manually.
 */
contract BondAssetsIntoTreasury is Script {

    // Note that the addresses are copied from the DEPLOYMENT.md doc file.
    Treasury  treasury    = Treasury (0x7521197233BD9235D2E39ad8D3D77c2843b2E837);
    ERC20Mock token       = ERC20Mock(0xD5A8842F698D6170661376880b5aE20C17fD1FC3);
    Oracle    tokenOracle = Oracle   (0x917443A163adC3BeBFCb5ffD3a9D8161bE503D79);

    function run() external {
        vm.startBroadcast();
        {
            // Set initial token's price to 1e18 (1$).
            tokenOracle.pushReport(1e18);

            // Mint 1,000 tokens to msg.sender, i.e. the address with which's
            // private key the script is executed.
            token.mint(msg.sender, 1_000e18);

            // Approve tokens to Treasury.
            token.approve(address(treasury), type(uint).max);

            // Register token inside the Treasury.
            treasury.registerAsset(address(token), address(tokenOracle));

            // List token as bondable inside the Treasury.
            treasury.listAssetAsBondable(address(token));

            // Bond tokens into Treasury.
            treasury.bond(address(token), 1_000e18);
        }
        vm.stopBroadcast();

        // Check balances.
        require(
            treasury.balanceOf(msg.sender) == 1_000e18,
            "BondAssetsIntoTreasury: Invalid amount of treasury tokens received through bonding"
        );
        require(
            token.balanceOf(address(treasury)) == 1_000e18,
            "BondAssetsIntoTreasury: Treasury fetched wrong amount of tokens during bonding"
        );

        vm.startBroadcast();
        {
            // Set token's price from 1e18 (1$) to 2e18 (2$).
            tokenOracle.purgeReports();
            tokenOracle.pushReport(2e18);

            // Trigger a Treasury rebase.
            treasury.rebase();
        }
        vm.stopBroadcast();

        // Check balance.
        require(
            treasury.balanceOf(msg.sender) == 2_000e18,
            "BondAssetsIntoTreasury: Invalid amount of treasury tokens after rebase"
        );
    }

}
